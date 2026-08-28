# Pi Agent Benchmark Report

**Date:** 2025-08-29  
**Agent:** pi coding agent (Qwen 3.6 / Qwen 2.5 30B A3 MoE, Q4_K_M)  
**Inference Server:** LM Studio (`host.docker.internal:1234`)  

---

## Hardware

| Component | Spec |
|-----------|------|
| GPU | NVIDIA RTX 3080 Ti (12 GB GDDR6X, ~912 GB/s bandwidth) |
| VRAM Budget | 12 GB total |
| Model Size | Qwen 30B A3 (~16-17 GB Q4 quantized — partial GPU offload) |

---

## Benchmark 1: Baseline Speed (Minimal Context)

**Prompt:** "List numbers from 1 to 50, one per line."  
**Input tokens:** ~24  

| Run | Output Tokens | Wall Time | **Tokens/sec** |
|-----|--------------|-----------|----------------|
| 1   | 256          | 11,530ms  | ~22.2 tok/s    |
| 2   | 256          | 10,828ms  | **~23.6 tok/s** |
| 3   | 256          | 10,909ms  | ~23.5 tok/s    |

### Baseline Average: **~23.1 tokens/sec**

---

## Benchmark 2: Context Window Stress Test

**Test:** Increasing input token count with fixed output (64 tokens) to measure KV cache / attention scaling impact.

| Input Tokens | Output | Speed | Visual |
|-------------|--------|-------|--------|
| **147**      | 64     | ~15.6 tok/s | [██████████████░░░░░░░░░░░░] |
| **395**      | 64     | ~15.6 tok/s | [██████████████░░░░░░░░░░░░] |
| **1,400**    | 64     | ~9.9 tok/s  | [█████████░░░░░░░░░░░░░░░░░] |
| **6,700**    | 64     | ~5.0 tok/s  | [█████░░░░░░░░░░░░░░░░░░░░░] |
| **13,400**   | 64     | ~1.9 tok/s  | [█░░░░░░░░░░░░░░░░░░░░░░░░░] |
| **26,900**   | 64     | ~1.5 tok/s  | [█░░░░░░░░░░░░░░░░░░░░░░░░░] |

### Degradation: **~90%** from fastest to slowest

---

## Analysis

### Speed by Context Range

| Context Size | Speed | Experience | Verdict |
|-------------|-------|------------|---------|
| < 500 tokens   | ~16 tok/s | Snappy ✅    | Ideal for quick tasks |
| 500 – 2K       | 10–16 tok/s | Acceptable ⚠️ | Fine for medium work |
| 2K – 7K        | 5–10 tok/s  | Noticeable lag | Watch your context |
| > 13K tokens   | ~2 tok/s    | Painful 😬    | Only use when necessary |

### Root Cause: VRAM Pressure + Attention Scaling

```
GPU Memory Budget (12 GB):
├── Model weights (Q4, partially offloaded):  ~8-9 GB ✅
├── KV Cache (@ 100K context, float16):       ~4-5 GB ❌
└── Working buffer:                            ~1 GB

Result: Past ~10-15K tokens, the attention layer spills to system RAM.
        Bandwidth drops from ~912 GB/s (VRAM) → ~30 GB/s (DDR4/5)
        = 30× slowdown per token examined in context.
```

---

## Recommendations

| Action | Why |
|--------|-----|
| **Keep active context under 5K tokens** | Best speed (~8-16 tok/s). Roughly first ~8-10 turns before compaction |
| **Use compaction liberally** | Don't wait until you're at 20K+ tokens — latency compounds fast |
| **Set LM Studio `n_ctx` to 32K–64K** | Balances max context with speed. 100K is overkill unless you need it |
| **Rely on `/tree` navigation & selective reading** | Don't dump entire codebases into context — read files on demand |

---

## Benchmark Test Code

### Baseline Speed Test

Three sequential runs measuring generation speed with minimal context (~24 input tokens).

```javascript
const http = require('http');

async function bench() {
  const payload = JSON.stringify({
    model: 'default-model',
    messages: [{role:'user', content:'List numbers from 1 to 50, one per line.'}],
    max_tokens: 256,
    temperature: 0.7
  });

  for (let i = 1; i <= 3; i++) {
    console.log('--- Run ' + i + ' ---');
    
    const start = Date.now();
    
    await new Promise((resolve, reject) => {
      const req = http.request({
        hostname: 'host.docker.internal',
        port: 1234,
        path: '/v1/chat/completions',
        method: 'POST',
        headers: {'Content-Type': 'application/json'}
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          const json = JSON.parse(data);
          const elapsed = Date.now() - start;
          const outputTokens = json.usage.completion_tokens;
          const inputTokens = json.usage.prompt_tokens;
          const speed = (outputTokens / (elapsed/1000)).toFixed(1);
          
          console.log('Input tokens:   ' + inputTokens);
          console.log('Output tokens:  ' + outputTokens);
          console.log('Wall time:      ' + elapsed + 'ms');
          console.log('Speed:          ~' + speed + ' tokens/sec');
        });
        resolve();
      });
      req.write(payload);
      req.end();
    });
    
    await new Promise(r => setTimeout(r, 500));
  }
}

bench().catch(console.error);
```

### Context Window Stress Test

Generates prompts of increasing length (147 → ~27K tokens), measures output speed with fixed 64-token response target. Reveals KV cache / attention scaling degradation.

```javascript
const http = require('http');

async function bench(promptText) {
  const payload = JSON.stringify({
    model: 'default-model',
    messages: [{role:'user', content: promptText}],
    max_tokens: 64,
    temperature: 0.7
  });

  return new Promise((resolve) => {
    const start = Date.now();
    const req = http.request({
      hostname: 'host.docker.internal',
      port: 1234,
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {'Content-Type': 'application/json'}
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const json = JSON.parse(data);
        const elapsed = Date.now() - start;
        resolve({
          inputTokens:  json.usage.prompt_tokens,
          outputTokens: json.usage.completion_tokens,
          elapsed,
          speed: (json.usage.completion_tokens / (elapsed/1000)).toFixed(1)
        });
      });
    });
    req.write(payload);
    req.end();
  });
}

function generateLongPrompt(tokenCount) {
  const paragraphs = [];
  for (let i = 0; i < tokenCount / 95; i++) {
    paragraphs.push(
      `Section ${i+1}: The architecture of modern software systems involves multiple interconnected components that work together to deliver reliable services. Each component must be designed with specific responsibilities, interfaces, and failure modes in mind. Design patterns such as the observer pattern, strategy pattern, and factory method help developers organize code in predictable ways.`
    );
  }
  paragraphs.push('\nFinally: what is 7 times 8? Answer directly.');
  return paragraphs.join('');
}

(async () => {
  const results = [];
  const targets = [100, 500, 2000, 5000, 10000, 20000];

  for (const target of targets) {
    let prompt = generateLongPrompt(target);
    let result = await bench(prompt);

    // Retry with double content if input was too short
    if (result.inputTokens < target * 0.7) {
      prompt = generateLongPrompt(target * 2);
      result = await bench(prompt);
    }

    results.push(result);
    console.log(
      `  Actual input:   ${result.inputTokens} tokens\n` +
      `  Output:         ${result.outputTokens} tokens\n` +
      `  Wall time:      ${result.elapsed}ms\n` +
      `  Speed:          ~${result.speed} tok/s`
    );

    await new Promise(r => setTimeout(r, 1000));
  }

  // Print summary with visual bars
  results.forEach((r) => {
    const barLen = Math.max(0, Math.min(50, parseInt(parseFloat(r.speed))));
    const bar = '\u2588'.repeat(barLen) + '\u2591'.repeat(50 - barLen);
    console.log(
      `  ${r.inputTokens.toString().padStart(6).padEnd(8)} tok \u2502 ~${parseFloat(r.speed).toFixed(1).padStart(7)} tok/s \u2502 [${bar}]`
    );
  });
})();
```

---

## Agent Capability Notes (This Session)

### What worked well
- Table-formatted comparisons for clear, scannable answers
- Appropriate tool usage (`bash`, `read`) without over-engineering
- Contextual awareness of hardware/model throughout conversation

### Where it struggled
- **Incorrect context window assumption** — stated 128K when actual limit was 32K; only corrected after user clarified. Should check config before asserting numbers.
- **No introspection API** — couldn't measure own token speed or context usage directly; had to parse session files and hit dead RPC endpoints first.
- **First pass on extensions vs skills** — dumped ~1,300 words of documentation for what should have been a quick comparison table.

### Tool limitations
| Capability | Status |
|-----------|--------|
| File read/write/edit | ✅ Built-in |
| Shell commands (`bash`) | ✅ Built-in |
| Measure own latency/token-speed | ❌ No introspection endpoint exposed to tools |
| See user prompt token counts | ❌ Session file only logs model-side tokens, not input tokenization |
| Self-evaluation loop | ❌ Not running during generation |
| Parallel multi-agent execution | ❌ Single agent per session (tools run in parallel per turn) |

---

*Generated by pi — Qwen 3.6 / Qwen 2.5 30B A3 MoE, Q4_K_M on RTX 3080 Ti.*
