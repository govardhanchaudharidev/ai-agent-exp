const http = require('http');

async function bench(promptText, timeoutMs = 120000) {
  const payload = JSON.stringify({
    model: 'qwen3.6',
    messages: [{role:'user', content: promptText}],
    max_tokens: 64,
    temperature: 0.7
  });

  return new Promise((resolve, reject) => {
    const start = Date.now();
    let timedOut = false;
    
    const req = http.request({
      hostname: 'host.docker.internal',
      port: 1234,
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      timeout: timeoutMs
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (timedOut) return;
        try {
          const json = JSON.parse(data);
          const elapsed = Date.now() - start;
          resolve({
            inputTokens:  json.usage.prompt_tokens,
            outputTokens: json.usage.completion_tokens,
            elapsed,
            speed: parseFloat((json.usage.completion_tokens / (elapsed/1000)).toFixed(1))
          });
        } catch(e) {
          reject(new Error('Failed to parse response: ' + data.substring(0,200)));
        }
      });
    });

    req.on('error', err => reject(err));
    req.on('timeout', () => {
      timedOut = true;
      req.destroy();
      reject(new Error('Request timed out after ' + timeoutMs + 'ms'));
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
  console.log('Context Window Stress Test\n==========================\n');
  const results = [];
  const targets = [100, 500, 2000, 5000, 10000, 20000];

  for (let idx = 0; idx < targets.length; idx++) {
    const target = targets[idx];
    console.log(`[${idx+1}/${targets.length}] Targeting ~${target.toLocaleString()} input tokens...`);

    let prompt = generateLongPrompt(target);
    
    try {
      let result = await bench(prompt, 60000);

      // Retry with double content if input was too short
      if (result.inputTokens < target * 0.7) {
        console.log('  Input tokens too low (' + result.inputTokens + '), retrying with double length...');
        prompt = generateLongPrompt(target * 2);
        result = await bench(prompt, 60000);
      }

      results.push(result);
      console.log(`  Actual input:   ${result.inputTokens.toLocaleString()} tokens`);
      console.log(`  Output:         ${result.outputTokens} tokens`);
      console.log(`  Wall time:      ${(result.elapsed/1000).toFixed(2)}s`);
      console.log(`  Speed:          ~${result.speed.toFixed(1)} tok/s\n`);

    } catch(e) {
      console.error(`  ERROR: ${e.message}\n`);
      results.push(null);
    }

    await new Promise(r => setTimeout(r, 2000));
  }

  // Print summary table
  console.log('\n==========================');
  console.log('SUMMARY');
  console.log('==========================\n');
  
  const validResults = results.filter(Boolean);
  if (validResults.length === 0) {
    console.log('No valid results collected.');
    return;
  }

  // Find max speed for bar scaling
  const maxSpeed = Math.max(...validResults.map(r => r.speed));
  
  validResults.forEach((r) => {
    if (!r) return;
    const barLen = Math.max(0, Math.min(50, Math.round((r.speed / maxSpeed) * 50)));
    const bar = '█'.repeat(barLen) + '░'.repeat(50 - barLen);
    console.log(`  ${r.inputTokens.toString().padStart(8).padEnd(12)} tok │ ~${r.speed.toFixed(1).padStart(7)} tok/s │ [${bar}]`);
  });

  const fastest = Math.max(...validResults.map(r => r.speed));
  const slowest = Math.min(...validResults.filter(r => r.speed > 0).map(r => r.speed));
  const degradation = ((1 - slowest/fastest) * 100).toFixed(0);
  
  console.log(`\nDegradation: ~${degradation}% from fastest to slowest`);
})().catch(console.error);
