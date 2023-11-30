from __future__ import annotations

from pathlib import Path
from typing import Any

from ann.ann import Ann

from ..config import log
from .base import InferenceModel


class AnnModel(InferenceModel):
    def __init__(
        self,
        model_name: str,
        cache_dir: Path | str | None = None,
        **model_kwargs: Any,
    ) -> None:
        super().__init__(model_name, cache_dir, **model_kwargs)
        tuning_file = model_kwargs.get("tuning_file")
        tuning_level = 3 if tuning_file else 1
        self.ann = Ann(tuning_level=tuning_level, tuning_file=tuning_file)
        log.debug(f"Instantitating ANN model '{self.model_name}' with tuning level {tuning_level}")
