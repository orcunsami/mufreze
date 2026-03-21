#!/usr/bin/env python3
"""
MUFREZE — LiteLLM Router
Unified LLM routing with fallbacks, retries, and cost tracking.

Usage:
    llm-route.py <model> <prompt> [--fallback model1,model2] [--max-retries N]

Models:
    anthropic/claude-sonnet-4-6    Claude Sonnet
    anthropic/claude-opus-4-6      Claude Opus
    anthropic/claude-haiku-4-5     Claude Haiku
    openai/gpt-4o                  GPT-4o
    openai/codex-mini              Codex Mini

Environment:
    ANTHROPIC_API_KEY    For Claude models
    OPENAI_API_KEY       For OpenAI models
"""

import sys
import os
import json
import argparse
from pathlib import Path

# Add mufreze venv
venv_path = Path(__file__).parent.parent / ".venv" / "lib"
for p in venv_path.glob("python*/site-packages"):
    sys.path.insert(0, str(p))

# Load .env
env_file = Path.home() / ".claude" / ".env"
if env_file.exists():
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

import litellm
from litellm import completion

# Suppress litellm logs
litellm.suppress_debug_info = True
litellm.set_verbose = False


def route(model: str, prompt: str, fallbacks: list = None, max_retries: int = 3) -> dict:
    """Route a prompt through LiteLLM with fallbacks."""
    models_to_try = [model] + (fallbacks or [])

    for i, m in enumerate(models_to_try):
        for attempt in range(max_retries):
            try:
                response = completion(
                    model=m,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.2,
                    max_tokens=4096,
                )

                result = {
                    "model": m,
                    "content": response.choices[0].message.content,
                    "usage": {
                        "input_tokens": response.usage.prompt_tokens,
                        "output_tokens": response.usage.completion_tokens,
                        "total_tokens": response.usage.total_tokens,
                    },
                    "cost": litellm.completion_cost(response),
                    "attempt": attempt + 1,
                    "fallback_index": i,
                }

                return result

            except Exception as e:
                error_msg = str(e)
                sys.stderr.write(
                    f"🎖️ MUFREZE LLM: {m} attempt {attempt + 1}/{max_retries} failed: {error_msg[:100]}\n"
                )

                if attempt == max_retries - 1 and i < len(models_to_try) - 1:
                    sys.stderr.write(
                        f"🎖️ MUFREZE LLM: Falling back to {models_to_try[i + 1]}\n"
                    )

    return {"error": "All models exhausted", "models_tried": models_to_try}


def main():
    parser = argparse.ArgumentParser(description="MUFREZE LiteLLM Router")
    parser.add_argument("model", help="Primary model (e.g., anthropic/claude-sonnet-4-6)")
    parser.add_argument("prompt", help="Prompt to send")
    parser.add_argument(
        "--fallback", help="Comma-separated fallback models", default=""
    )
    parser.add_argument("--max-retries", type=int, default=3, help="Max retries per model")
    parser.add_argument("--json", action="store_true", help="Output full JSON result")

    args = parser.parse_args()

    fallbacks = [f.strip() for f in args.fallback.split(",") if f.strip()]
    result = route(args.model, args.prompt, fallbacks, args.max_retries)

    if args.json:
        print(json.dumps(result, indent=2, default=str))
    elif "error" in result:
        sys.stderr.write(f"❌ MUFREZE LLM: {result['error']}\n")
        sys.exit(1)
    else:
        print(result["content"])
        sys.stderr.write(
            f"🎖️ MUFREZE LLM: {result['model']} | "
            f"tokens: {result['usage']['total_tokens']} | "
            f"cost: ${result['cost']:.4f} | "
            f"attempt: {result['attempt']}\n"
        )


if __name__ == "__main__":
    main()
