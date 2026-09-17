const axios = require('axios');

async function submitIndexNow() {
  const host = "www.truthworld.in";
  const key = "truthworld-indexnow-key-2026";
  const keyLocation = `https://${host}/${key}.txt`;
  const urlList = [
    `https://${host}/advertisements`,
    `https://${host}/studio`,
    `https://${host}/browse`,
    `https://${host}/trending`
  ];

  const payload = {
    host,
    key,
    keyLocation,
    urlList
  };

  console.log(`Submitting ${urlList.length} URLs to IndexNow...`);
  console.log(JSON.stringify(payload, null, 2));

  try {
    const response = await axios.post("https://api.indexnow.org/IndexNow", payload, {
      headers: { "Content-Type": "application/json; charset=utf-8" },
      timeout: 15000
    });

    console.log(`IndexNow Response Status: ${response.status} (${response.statusText})`);
    if (response.status === 200 || response.status === 202) {
      console.log("Successfully submitted URLs to IndexNow! Search engines (Bing, Yandex, etc.) have been notified.");
    } else {
      console.log("Response data:", response.data);
    }
  } catch (err) {
    console.error("IndexNow submission failed:", err?.response?.data || err?.message || err);
  }
}

submitIndexNow();
