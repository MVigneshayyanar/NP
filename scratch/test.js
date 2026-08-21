const fetch = require('node-fetch');
(async () => {
    console.log("Fetching Go Gateway...");
    let res = await fetch("http://localhost:3000/internal/dashboard/floor-plans/");
    console.log("Go Gateway Status:", res.status);
    console.log("Go Gateway Body:", await res.text());

    console.log("Fetching Django Directly...");
    res = await fetch("http://localhost:8000/internal/dashboard/floor-plans/");
    console.log("Django Status:", res.status);
    console.log("Django Body:", await res.text());
})();
