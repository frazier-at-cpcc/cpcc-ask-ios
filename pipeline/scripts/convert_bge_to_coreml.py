"""One-time: convert BAAI/bge-small-en-v1.5 to a CoreML mlpackage.

Inputs at runtime: int32 input_ids (1, max_len), int32 attention_mask (1, max_len).
Output: float32 sentence_embedding (1, 384) — L2-normalized mean-pooled.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer

# Patch coremltools _cast to handle length-1 arrays (newer torch trace produces these)
from coremltools.converters.mil.frontend.torch import ops as _ct_ops
from coremltools.converters.mil import Builder as _mb


def _patched_cast(context, node, dtype, dtype_name):
    inputs = _ct_ops._get_inputs(context, node, expected=1)
    x = inputs[0]
    if not (len(x.shape) == 0 or np.all([d == 1 for d in x.shape])):
        raise ValueError("input to cast must be either a scalar or a length 1 tensor")
    if x.can_be_folded_to_const():
        if not isinstance(x.val, dtype):
            val = x.val
            if hasattr(val, "shape") and val.shape != ():
                val = val.flatten()[0]
            res = _mb.const(val=dtype(val), name=node.name)
        else:
            res = x
    elif len(x.shape) > 0:
        x = _mb.squeeze(x=x, name=node.name + "_item")
        res = _mb.cast(x=x, dtype=dtype_name, name=node.name)
    else:
        res = _mb.cast(x=x, dtype=dtype_name, name=node.name)
    context.add(res, node.name)


_ct_ops._cast = _patched_cast


MODEL_NAME = "BAAI/bge-small-en-v1.5"
MAX_LEN = 256


class BGEEmbedder(torch.nn.Module):
    def __init__(self, model_name: str = MODEL_NAME):
        super().__init__()
        self.bert = AutoModel.from_pretrained(model_name, attn_implementation="eager")

    def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
        outputs = self.bert(input_ids=input_ids, attention_mask=attention_mask)
        last = outputs.last_hidden_state
        mask = attention_mask.unsqueeze(-1).float()
        summed = (last * mask).sum(dim=1)
        denom = mask.sum(dim=1).clamp(min=1e-9)
        pooled = summed / denom
        normalized = torch.nn.functional.normalize(pooled, p=2, dim=1)
        return normalized


def convert(out_path: Path) -> None:
    model = BGEEmbedder().eval()
    sample_ids = torch.zeros((1, MAX_LEN), dtype=torch.int64)
    sample_mask = torch.ones((1, MAX_LEN), dtype=torch.int64)

    traced = torch.jit.trace(model, (sample_ids, sample_mask), strict=False)

    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, MAX_LEN), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, MAX_LEN), dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="sentence_embedding", dtype=np.float32)],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS17,
        convert_to="mlprogram",
    )
    mlmodel.short_description = "BAAI/bge-small-en-v1.5 sentence embedding (mean-pooled, L2-normalized)"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(out_path))
    print(f"Saved {out_path}")

    tok = AutoTokenizer.from_pretrained(MODEL_NAME)
    tok_dir = out_path.parent / "BGETokenizer"
    tok_dir.mkdir(parents=True, exist_ok=True)
    tok.save_pretrained(tok_dir)
    print(f"Saved tokenizer to {tok_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path,
                        default=Path("AskCPCC/Resources/BGEEmbedder.mlpackage"))
    args = parser.parse_args()
    convert(args.out)
