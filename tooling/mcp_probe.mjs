import {Client} from '/Users/juancarlos/.npm/_npx/f709a66c57c635d0/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from '/Users/juancarlos/.npm/_npx/f709a66c57c635d0/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import fs from 'node:fs';
const root='/Users/juancarlos/Downloads/jogo/Tower Defense';
const client=new Client({name:'ac1-verification',version:'1.0.0'});
const transport=new StdioClientTransport({command:'/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node',args:['/Users/juancarlos/.npm/_npx/f709a66c57c635d0/node_modules/@yanhuifair/godot-mcp/dist/index.js','-p',root,'-g','/Users/juancarlos/Downloads/Godot.app/Contents/MacOS/Godot'],stderr:'pipe'});
transport.stderr?.on('data',d=>process.stderr.write(d));
try { await client.connect(transport); const list=await client.listTools(); fs.mkdirSync(root+'/docs/ac1/evidence',{recursive:true}); fs.writeFileSync(root+'/docs/ac1/evidence/mcp_tools.json',JSON.stringify(list,null,2));
if(process.argv[2]) { const calls=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));const results=[];for(const call of calls) {const result=await client.callTool(call);results.push({call,result});console.log(JSON.stringify({call,result})); if(call.name.includes('run_project')) await new Promise(r=>setTimeout(r,4000));} fs.writeFileSync(root+'/docs/ac1/evidence/mcp_results.json',JSON.stringify(results,null,2)); }
else console.log(JSON.stringify(list.tools.filter(t=>/godot|project_info|run_project|stop|output|status/.test(t.name))));
} finally {await client.close();}
