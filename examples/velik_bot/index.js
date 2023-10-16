Twitch.ext.onAuthorized( auth =>
  fetch(`https://cfg.nakilon.su/`).
  then(x=>x.json()).
  then( x =>
    fetch(`https://${x.velik_bot_rep}/${auth.channelId}.json`).
    then(x=>x.json()).
    then( ([date,array]) => {
      document.getElementById("div").innerText = `last data update: ${date}`;
      const table = document.getElementById("table");
      table.innerHTML = "<th>reputation</th>";
      (function(_){
        array.toReversed().slice(0,5).forEach(([rating, who], i) => {
          _(rating, who.join(", "));
        });
        _("...", "");
        _(array[0][0], array[0][1]);
      })( (a,b) => {
        const tr = document.createElement("tr");
        const tda = document.createElement("td"); tda.innerText = a; tr.append(tda); tda.style["text-align"] = "center";
        const tdb = document.createElement("td"); tdb.innerText = b; tr.append(tdb);
        table.append(tr);
      } )
    } )
  )
)
