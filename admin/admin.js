let products=[],orders=[],tab="dashboard",saving=false,loggingIn=false;const $=s=>document.querySelector(s),money=SW.money;
async function isAdmin(){let {data,error}=await SW.client.rpc("is_admin");return !error&&data===true}
async function init(){if(!SW.ready())return login("Add Supabase credentials in assets/config.js first.");let {data}=await SW.client.auth.getSession();if(!data.session)return login();if(!(await isAdmin())){await SW.client.auth.signOut();return login("This account is not an admin account.")}await loadData();render()}
function login(msg=""){document.getElementById("adminApp").innerHTML=`<div class="admin-login"><div class="login-card"><div class="logo"><span class="logo-mark">S</span><span><b>SEAMEN'S COLLECTION</b><small>ADMIN PANEL</small></span></div><h2>Admin Login</h2>${msg?`<p class="danger">${esc(msg)}</p>`:""}<input id="email" type="email" placeholder="Admin email"><input id="password" type="password" placeholder="Password"><button class="btn dark" onclick="doLogin()">Login</button></div></div>`}
async function doLogin(){if(loggingIn)return;let email=$("#email").value.trim(),password=$("#password").value;if(!email||!password)return alert("Enter email and password.");loggingIn=true;let {error}=await SW.client.auth.signInWithPassword({email,password});if(error){loggingIn=false;return alert(error.message)}if(!(await isAdmin())){await SW.client.auth.signOut();loggingIn=false;return login("This account is not an admin account.")}await loadData();loggingIn=false;render()}
async function loadData(){let p=await SW.client.from("products").select("*").order("created_at",{ascending:false});let o=await SW.client.from("orders").select("*").order("created_at",{ascending:false});if(p.error)alert(p.error.message);if(o.error)alert(o.error.message);products=p.data||[];orders=o.data||[]}
function render(){document.getElementById("adminApp").innerHTML=`<div class="admin-shell"><aside class="side"><h1>SEAMEN'S</h1><small>COLLECTION · ADMIN</small><nav>${["dashboard","products","orders"].map(x=>`<button class="${tab===x?"active":""}" onclick="go('${x}')">${x[0].toUpperCase()+x.slice(1)}</button>`).join("")}<button onclick="logout()">Logout</button><button onclick="location.href='../'">View Store ↗</button></nav></aside><main class="admin-main">${tab==="dashboard"?dash():tab==="products"?prodPage():orderPage()}</main></div>`}
function go(x){tab=x;render()}
function dash(){let total=orders.reduce((a,o)=>a+Number(o.total),0);return`<div class="admin-top"><h2>Dashboard</h2></div><div class="cards"><div class="stat"><div class="muted">Products</div><b>${products.length}</b></div><div class="stat"><div class="muted">Orders</div><b>${orders.length}</b></div><div class="stat"><div class="muted">Sales</div><b>${money(total)}</b></div><div class="stat"><div class="muted">New</div><b>${orders.filter(o=>o.status==="New").length}</b></div></div><div class="panel"><h3>Recent orders</h3>${table(orders.slice(0,8))}</div>`}
function table(a){if(!a.length)return"<div class='empty'>No orders yet.</div>";return`<div class="orders-scroll"><table class="admin-table"><tr><th>Order</th><th>Customer</th><th>Total</th><th>Status</th><th></th></tr>${a.map(o=>`<tr><td>${o.order_number}</td><td>${esc(o.customer_name)}<br><span class="muted">${esc(o.city)} · ${esc(o.phone)}</span></td><td>${money(o.total)}</td><td><select onchange="status('${o.id}',this.value)">${["New","Confirmed","Packed","Shipped","Delivered","Cancelled"].map(s=>`<option ${s===o.status?"selected":""}>${s}</option>`).join("")}</select></td><td><button onclick="view('${o.id}')">View</button> <button onclick="delOrder('${o.id}')">Delete</button></td></tr>`).join("")}</table></div>`}
function orderPage(){return`<div class="admin-top"><h2>Orders</h2></div><div class="panel ${orders.length>1?'compact-orders':''}">${table(orders)}</div>`}
function prodPage(){return`<div class="admin-top"><h2>Products</h2><button class="btn dark" onclick="openProductForm()">+ Add Product</button></div><div class="panel"><table class="admin-table"><tr><th>Image</th><th>Name</th><th>Category</th><th>Price</th><th>Stock</th><th></th></tr>${products.map(p=>`<tr><td class="mini-thumb">${p.image_url?`<img src="${esc(p.image_url)}">`:"—"}</td><td>${esc(p.name)}</td><td>${p.category}</td><td>${money(p.price)}</td><td>${p.stock}</td><td><button onclick="openProductForm('${p.id}')">Edit</button> <button onclick="del('${p.id}')">Delete</button></td></tr>`).join("")}</table></div><div id="modal"></div>`}
function openProductForm(id){let p=products.find(x=>x.id===id)||{name:"",category:"Beads",price:0,stock:0,description:"",image_url:"",active:true};document.getElementById("modal").innerHTML=`<div class="modal open"><div class="modal-box"><button class="close" onclick="$('#modal').innerHTML=''">×</button><h3>${id?"Edit":"Add"} Product</h3><input id="pn" placeholder="Name" value="${esc(p.name)}"><select id="pc">${["Beads","Resin","Crochet"].map(x=>`<option ${x===p.category?"selected":""}>${x}</option>`).join("")}</select><input id="pp" type="number" placeholder="Price" value="${p.price}"><input id="ps" type="number" placeholder="Stock" value="${p.stock}"><textarea id="pd" placeholder="Description">${esc(p.description)}</textarea><label class="upload-label">Product image from gallery<input id="pimg" type="file" accept="image/*"></label>${p.image_url?`<div class="image-preview"><img src="${esc(p.image_url)}"><small>Current image will stay unless a new image is selected.</small></div>`:""}<label><input id="pa" type="checkbox" ${p.active?"checked":""}> Active</label><br><button class="btn dark" onclick="save('${id||""}')">Save</button></div></div>`}
async function del(id){
  if(!confirm("Delete this product permanently?")) return;

  let r = await SW.client
    .from("products")
    .delete()
    .eq("id", id);

  if(r.error){
    alert("Delete failed: " + r.error.message);
    return;
  }

  await loadData();
  render();
}
async function del(id){if(!confirm("Delete this product?"))return;let r=await SW.client.from("products").update({active:false}).eq("id",id);if(r.error)alert(r.error.message);await loadData();render()
async function status(id,s){let r=await SW.client.rpc("admin_update_order_status",{p_order_id:id,p_status:s});if(r.error){alert(r.error.message);return}await loadData();render()}
async function delOrder(id){if(!confirm("Delete this order permanently?"))return;let r=await SW.client.from("orders").delete().eq("id",id);if(r.error)return alert(r.error.message);await loadData();render()}
async function view(id){let o=orders.find(x=>x.id===id),r=await SW.client.from("order_items").select("*").eq("order_id",id);alert(`Order ${o.order_number}\n\n${o.customer_name}\n${o.phone}\n${o.city}\n${o.address}\n\nPayment: ${o.payment_method}\nTotal: ${money(o.total)}\n\n${(r.data||[]).map(i=>i.product_name+" × "+i.quantity).join("\n")}`)}
async function logout(){await SW.client.auth.signOut();login()}
function esc(x){return String(x??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;")}
window.go=go;window.doLogin=doLogin;window.openProductForm=openProductForm;window.save=save;window.del=del;window.status=status;window.view=view;window.delOrder=delOrder;
window.logout=logout;init();
