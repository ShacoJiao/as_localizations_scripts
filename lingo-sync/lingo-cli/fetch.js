import https from 'https';
import http from 'http';

export default function fetch(options) {
  return new Promise((resolve, reject) => {
    const request = options.port === 443 ? https.request : http.request;
    const req = request(options, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve(data);
      });
    });
    req.on('error', (e) => {
      reject(e);
    });
    req.end();
  })
}
