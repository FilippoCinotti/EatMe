"""Image generation providers. All run locally; none calls a paid API.

A provider has ``name``, ``check()`` (raise ``ProviderUnavailable`` when it
cannot run on this machine), ``generate(prompt, seed, width, height,
short_prompt=None)`` returning a PIL image, and ``metadata()`` for audit records. Register a new
local/open model in ``PROVIDERS`` to swap it in with ``--provider``.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field

DEFAULT_MODEL = 'black-forest-labs/FLUX.1-schnell'
GPU_REQUIREMENTS = 'scripts/recipe_images/requirements-gpu.txt'


class ProviderUnavailable(RuntimeError):
    """The provider cannot run here; nothing was claimed or written."""


@dataclass
class FluxSchnellProvider:
    """FLUX.1-schnell (Apache-2.0) through Hugging Face Diffusers.

    schnell is timestep-distilled: 4 steps, no classifier-free guidance, and
    its T5 text encoder reads at most 256 tokens.
    """
    model: str = os.environ.get('RECIPE_IMAGE_MODEL', DEFAULT_MODEL)
    revision: str | None = os.environ.get('RECIPE_IMAGE_MODEL_REVISION') or None
    device: str | None = os.environ.get('RECIPE_IMAGE_DEVICE') or None
    offload: str = 'model'          # none | model | sequential
    steps: int = 4
    max_sequence_length: int = 256
    allow_cpu: bool = False
    name: str = 'flux-schnell'
    _pipe: object = field(default=None, repr=False)
    _torch: object = field(default=None, repr=False)

    def check(self):
        try:
            import diffusers  # noqa: F401
            import torch
        except ImportError as error:
            raise ProviderUnavailable(
                f'{error.name} is not installed. On the GPU machine run: pip install -r {GPU_REQUIREMENTS}') from error
        self._torch = torch
        if self.device is None:
            if torch.cuda.is_available():
                self.device = 'cuda'
            elif getattr(torch.backends, 'mps', None) and torch.backends.mps.is_available():
                self.device = 'mps'
            else:
                self.device = 'cpu'
        if self.device == 'cpu' and not self.allow_cpu:
            raise ProviderUnavailable(
                'No CUDA or Apple Silicon GPU found. FLUX.1-schnell needs a GPU with about 16 GB of memory '
                '(24 GB recommended); run the same command on a GPU machine (see docs/catalog/recipe-images.md). '
                'Use --allow-cpu only for smoke tests with a tiny model.')
        return self

    def _load(self):
        if self._pipe is not None:
            return self._pipe
        from diffusers import FluxPipeline
        torch = self._torch
        # bfloat16 on CUDA, float16 on Apple Silicon; float32 on CPU, where half precision is very slow.
        dtype = {'cuda': torch.bfloat16, 'mps': torch.float16}.get(self.device, torch.float32)
        pipe = FluxPipeline.from_pretrained(self.model, revision=self.revision, torch_dtype=dtype)
        if self.device == 'cuda' and self.offload == 'model':
            pipe.enable_model_cpu_offload()
        elif self.device == 'cuda' and self.offload == 'sequential':
            pipe.enable_sequential_cpu_offload()
        else:
            pipe.to(self.device)
        pipe.set_progress_bar_config(disable=True)
        self._pipe = pipe
        return pipe

    def token_count(self, prompt):
        pipe = self._load()
        tokenizer = getattr(pipe, 'tokenizer_2', None)
        return len(tokenizer(prompt).input_ids) if tokenizer is not None else None

    def generate(self, prompt, seed, width, height, short_prompt=None):
        pipe = self._load()
        generator = self._torch.Generator(device='cpu').manual_seed(int(seed))
        # CLIP (77 tokens) gets the short summary; the T5 encoder gets the full prompt.
        result = pipe(prompt=short_prompt or prompt, prompt_2=prompt, num_inference_steps=self.steps, guidance_scale=0.0,
                      max_sequence_length=self.max_sequence_length, width=width, height=height,
                      generator=generator, output_type='pil')
        return result.images[0]

    def metadata(self):
        import diffusers
        info = {'provider': self.name, 'model': self.model, 'steps': self.steps, 'guidance_scale': 0.0,
                'max_sequence_length': self.max_sequence_length, 'device': self.device,
                'diffusers': diffusers.__version__, 'torch': self._torch.__version__}
        if self.revision:
            info['revision'] = self.revision
        return info


PROVIDERS = {'flux-schnell': FluxSchnellProvider}


def make_provider(name, **options):
    try:
        factory = PROVIDERS[name]
    except KeyError:
        raise ProviderUnavailable(f'unknown provider {name!r}; available: {", ".join(sorted(PROVIDERS))}') from None
    return factory(**{k: v for k, v in options.items() if v is not None})
