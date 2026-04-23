"""Defensive helpers for routing user-controlled text into LLM prompts.

Every field that a usuaria can type freely (chat messages, goals, notes,
meal/menu transcriptions) eventually lands in a Vertex system prompt. Without
defensive handling, a motivated user — or a compromised upstream client — can
inject instructions that hijack the model, leak system prompts, or flip the
safety guardrails off. The helpers in this module centralize the defensive
pass so every prompt builder applies the same rules.

Design constraints:

* Sanitization must never throw. A bad input returns a safe placeholder so the
  remote provider still receives a well-formed prompt and can fall back to
  the deterministic local output path.
* We prefer structural mitigations (delimiter removal, length cap) over
  content heuristics. Heuristic filtering on Spanish + English mixes tends to
  break legitimate copy more than it blocks attackers.
* Downstream prompts already wrap user content in clearly-labelled blocks
  (``USER CONTEXT INJECTION``, ``USER MESSAGE``). This helper guarantees that
  those boundaries cannot be short-circuited by the user injecting their own
  section headers or model-level delimiters.
"""

from __future__ import annotations

import re

# Known chat-template and chat-ml style delimiters from Anthropic, OpenAI, the
# Llama family, and Gemini. Each has been observed in real prompt-injection
# attempts and must never be echoed verbatim inside a prompt built on top of
# untrusted text.
_INJECTION_MARKERS = (
    "<|im_start|>",
    "<|im_end|>",
    "<|system|>",
    "<|user|>",
    "<|assistant|>",
    "<|endoftext|>",
    "<|start_header_id|>",
    "<|end_header_id|>",
    "<|eot_id|>",
    "[INST]",
    "[/INST]",
    "<<SYS>>",
    "<</SYS>>",
    "<system>",
    "</system>",
    "<user>",
    "</user>",
    "<assistant>",
    "</assistant>",
    "<|channel|>",
    "<|message|>",
)

# Matches ASCII + Latin-1 C0 / C1 control codes except newline and tab so that
# common multi-line scans still render cleanly.
_CONTROL_CHARS_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]")

# Matches a triple backtick fence introducing an attempted "code block" hijack.
# We keep single backticks intact (users often use them casually) but collapse
# any attempt to open a fenced block used to wrap spoofed instructions.
_TRIPLE_FENCE_RE = re.compile(r"```+")


def sanitize_prompt_text(
    text: str | None,
    *,
    max_length: int = 2000,
    fallback: str = "",
) -> str:
    """Return a version of ``text`` that is safe to splice into a prompt.

    The output preserves meaning for legitimate copy while neutralizing known
    injection primitives:

    * Control characters (except ``\\n`` and ``\\t``) are removed.
    * Known chat-template delimiters are replaced with ``[filtered]`` so the
      model cannot be tricked into treating user text as system instructions.
    * Triple backtick fences are collapsed to single backticks.
    * The result is truncated to ``max_length`` characters; truncation is
      signalled with a trailing ``…`` so downstream code can reason about it.
    * Empty input collapses to ``fallback``.
    """
    if text is None:
        return fallback
    value = text
    if not isinstance(value, str):
        value = str(value)

    cleaned = _CONTROL_CHARS_RE.sub("", value)
    cleaned = _TRIPLE_FENCE_RE.sub("`", cleaned)

    lowered = cleaned.lower()
    for marker in _INJECTION_MARKERS:
        if marker.lower() in lowered:
            # Replace case-insensitively by iterating match positions.
            cleaned = _replace_case_insensitive(cleaned, marker, "[filtered]")
            lowered = cleaned.lower()

    trimmed = cleaned.strip()
    if not trimmed:
        return fallback

    if len(trimmed) > max_length:
        # Reserve one code point for the ellipsis sentinel so downstream
        # observers can tell the text was cut.
        trimmed = trimmed[: max_length - 1].rstrip() + "…"

    return trimmed


def _replace_case_insensitive(haystack: str, needle: str, replacement: str) -> str:
    pattern = re.compile(re.escape(needle), flags=re.IGNORECASE)
    return pattern.sub(replacement, haystack)
