const http = require('http');

async function bench() {
  const payload = JSON.stringify({
    model: 'qwen3.6',
    messages: [{role:'user', content:'List numbers from 1 to 50, one per line.'}],
    max_tokens: 256,
    temperature: 0.7
  });

  const results = [];

  for (let i = 1; i <= 3; i++) {
    console.log('--- Run ' + i + ' ---');
    
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
          const elapsed = Date.now() - req.start;
          const outputTokens = json.usage.completion_tokens;
          const inputTokens = json.usage.prompt_tokens;
          const speed = (outputTokens / (elapsed/1000)).toFixed(1);
          
          console.log('  Input tokens:   ' + inputTokens);
          console.log('  Output tokens:  ' + outputTokens);
          console.log('  Wall time:      ' + elapsed + 'ms');
          console.log('  Speed:          ~' + speed + ' tokens/sec');

          results.push({inputTokens, outputTokens, elapsed, speed: parseFloat(speed)});
          resolve();
        });
      });
      req.start = Date.now();
      req.write(payload);
      req.end();
    });
    
    await new Promise(r => setTimeout(r, 500));
  }

  const avgSpeed = (results.reduce((s,r) => s + r.speed, 0) / results.length).toFixed(1);
  console.log('\n=== Baseline Average: ~' + avgSpeed + ' tokens/sec ===');
}

bench().catch(console.error);
