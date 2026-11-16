"""Build-only export from the publisher's trained checkpoint. Never trains a model.
Run using Python with isolated torch 2.6.0 CPU, torchvision 0.21.0 and onnx 1.17.0.
The checkpoint is loaded with weights_only=True; arbitrary pickle globals are denied.
"""
from pathlib import Path
import hashlib
import json
import torch
from torchvision.models import mobilenet_v2

torch.set_num_threads(2)
checkpoint_path = Path('downloads/food101-trained.bin')
checkpoint = torch.load(checkpoint_path, map_location='cpu', weights_only=True)
weights = checkpoint.get('state_dict', checkpoint)
weights = {k.removeprefix('module.'): v for k, v in weights.items()}
model = mobilenet_v2(num_classes=101)
model.load_state_dict(weights, strict=True)
model.eval()
target = Path('public/vision/food101.onnx')
with torch.inference_mode():
    sample = torch.zeros(1, 3, 224, 224)
    out = model(sample).flatten()
    assert float(out.max() - out.min()) > 1, 'Reject degenerate model outputs'
    torch.onnx.export(model, sample, str(target), input_names=['input'], output_names=['logits'], opset_version=17, dynamo=False)
metadata = {
    'publisher': 'AlexKoff88/mobilenet_v2_food101',
    'revision': '7d05d3878ee7f2aad7ad159018a8e5fdb4953d41',
    'checkpoint_sha256': hashlib.sha256(checkpoint_path.read_bytes()).hexdigest(),
    'model_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    'bytes': target.stat().st_size,
    'format': 'ONNX opset 17, NCHW RGB, resize short edge 256, center crop 224, ImageNet normalization',
    'classes': 101,
    'license': 'Apache-2.0',
    'zero_input_logit_range': [float(out.min()), float(out.max())],
    'note': 'Exported from trained checkpoint; publisher ONNX was rejected after degenerate-output checks.'
}
Path('public/vision/model-info.json').write_text(json.dumps(metadata, indent=2), encoding='utf8')
print(json.dumps(metadata))
