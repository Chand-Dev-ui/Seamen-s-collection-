const cfg=window.SEAWAIS_CONFIG||{};
const client=(window.supabase&&typeof cfg.SUPABASE_URL==='string'&&cfg.SUPABASE_URL.startsWith('http')&&typeof cfg.SUPABASE_ANON_KEY==='string'&&cfg.SUPABASE_ANON_KEY.length>20)?window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY):null;
window.SW={client,cfg,money:n=>"Rs. "+Number(n||0).toLocaleString("en-PK"),ready:()=>!!client};
