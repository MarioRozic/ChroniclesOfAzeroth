const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1000, height: 720 }, deviceScaleFactor: 2 });
  for (const [pg, n] of [['fellows','1-fellows-compare'],['sharing','2-sharing-settings'],['char','3-brag-menu']]) {
    await p.goto('file://' + __dirname + '/preview4.html?d=B&p=' + pg);
    await p.waitForTimeout(1500);
    await p.screenshot({ path: __dirname + '/v6/' + n + '.png' });
  }
  await b.close();
})();
