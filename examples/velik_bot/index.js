Twitch.ext.onAuthorized( auth =>
  fetch(`https://cfg.nakilon.su/`).
  then(x=>x.json()).
  then( x =>
    fetch(`https://${x.velik_bot_rep}/${auth.channelId}.json`).
    then(x=>x.json()).
    then( ([date,array]) => {
      document.getElementById("div").innerText = `last data update: ${date}`;
      const table = document.getElementById("table");
      table.innerHTML = "<tr><th>reputation</th><th></th></tr><tr><td><hr noshade color='#f2eaff' size='2px' width='80%'></td><td><hr noshade color='#a970ff' size='2px' width='90%'></td></tr>";
      (function(_){
        array.toReversed().slice(0,5).forEach(([rating, who], i) => {
          _(rating, who);
        });
        _("...", []);
        _(array[0][0], array[0][1]);
      })( (a,b) => {
        const tr = document.createElement("tr");
        const tda = document.createElement("td"); tda.innerText = a; tr.append(tda); tda.style["text-align"] = "center";
        const tdb = document.createElement("td");
        b.forEach(who => {
          const a = document.createElement("a");
          a.href = `https://twitch.tv/${who}`;
          a.append(who);
          tdb.append(a);
        } );
        tr.append(tdb);
        table.append(tr);
      } )
    } )
  )
)
