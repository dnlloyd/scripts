import got from 'got';
import assert from 'assert';

const options = {
  url: 'https://SOMEURL.com/index.html',
  headers: {
    'x-api-key': '123DUMMY456',
    'Content-Type': 'application/json'
  }
}


got.get(options,
    function (err, response, body) {
      assert.equal(response.statusCode, 200, 'Expected a 200 OK response');
      console.log('Response:', body.json);
    }
);
