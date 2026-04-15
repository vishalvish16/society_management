import { useState } from "react";

const SOCIETIES = [
  { id: 1, name: "Shree Residency", city: "Ahmedabad", state: "Gujarat", plan: "Premium", units: 120, adminName: "Rajesh Mehta", adminPhone: "9876543210", adminEmail: "rajesh@shreeres.com", status: "Active", registeredOn: "2024-08-12", wings: 3 },
  { id: 2, name: "Green Valley CHS", city: "Pune", state: "Maharashtra", plan: "Standard", units: 80, adminName: "Sunita Patil", adminPhone: "9823456789", adminEmail: "sunita@greenvalley.com", status: "Trial", registeredOn: "2025-01-03", wings: 2 },
  { id: 3, name: "Lakeview Apartments", city: "Mumbai", state: "Maharashtra", plan: "Basic", units: 48, adminName: "Anil Sharma", adminPhone: "9712345678", adminEmail: "anil@lakeview.com", status: "Active", registeredOn: "2024-11-20", wings: 1 },
  { id: 4, name: "Sunrise Heights", city: "Surat", state: "Gujarat", plan: "Premium", units: 200, adminName: "Priya Desai", adminPhone: "9654321098", adminEmail: "priya@sunrise.com", status: "Suspended", registeredOn: "2024-06-05", wings: 4 },
  { id: 5, name: "Palm Grove Society", city: "Hyderabad", state: "Telangana", plan: "Standard", units: 64, adminName: "Venkat Rao", adminPhone: "9988776655", adminEmail: "venkat@palmgrove.com", status: "Active", registeredOn: "2025-02-14", wings: 2 },
];

const PLAN_COLORS = { Premium: "#7C3AED", Standard: "#0284C7", Basic: "#059669" };
const STATUS_COLORS = { Active: "#16A34A", Trial: "#D97706", Suspended: "#DC2626", Inactive: "#6B7280" };
const STATUS_BG = { Active: "#DCFCE7", Trial: "#FEF3C7", Suspended: "#FEE2E2", Inactive: "#F3F4F6" };

const STEPS = ["Society Details", "Subscription Plan", "Admin Setup", "Review & Confirm"];

export default function App() {
  const [view, setView] = useState("list"); // list | add | detail | resetpwd
  const [societies, setSocieties] = useState(SOCIETIES);
  const [selected, setSelected] = useState(null);
  const [step, setStep] = useState(0);
  const [search, setSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState("All");
  const [resetModal, setResetModal] = useState(null);
  const [resetType, setResetType] = useState("auto");
  const [manualPwd, setManualPwd] = useState("");
  const [resetDone, setResetDone] = useState(false);
  const [toast, setToast] = useState(null);

  const [form, setForm] = useState({
    name: "", city: "", state: "", pin: "", address: "", type: "Apartment",
    wings: "", units: "", plan: "Standard", trial: true, trialDays: "30",
    adminName: "", adminPhone: "", adminEmail: "", adminRole: "Secretary"
  });

  const showToast = (msg, type = "success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const filtered = societies.filter(s => {
    const matchSearch = s.name.toLowerCase().includes(search.toLowerCase()) ||
      s.city.toLowerCase().includes(search.toLowerCase()) ||
      s.adminName.toLowerCase().includes(search.toLowerCase());
    const matchStatus = filterStatus === "All" || s.status === filterStatus;
    return matchSearch && matchStatus;
  });

  const handleAddSociety = () => {
    const newSociety = {
      id: societies.length + 1,
      name: form.name, city: form.city, state: form.state,
      plan: form.plan, units: parseInt(form.units) || 0,
      adminName: form.adminName, adminPhone: form.adminPhone,
      adminEmail: form.adminEmail, status: form.trial ? "Trial" : "Active",
      registeredOn: new Date().toISOString().split("T")[0], wings: parseInt(form.wings) || 1
    };
    setSocieties([...societies, newSociety]);
    setView("list");
    setStep(0);
    setForm({ name:"",city:"",state:"",pin:"",address:"",type:"Apartment",wings:"",units:"",plan:"Standard",trial:true,trialDays:"30",adminName:"",adminPhone:"",adminEmail:"",adminRole:"Secretary" });
    showToast(`Society "${newSociety.name}" registered successfully!`);
  };

  const handleToggleStatus = (id) => {
    setSocieties(societies.map(s => s.id === id ? { ...s, status: s.status === "Active" ? "Suspended" : "Active" } : s));
  };

  const handleResetSubmit = () => {
    setResetDone(true);
    setTimeout(() => {
      setResetModal(null);
      setResetDone(false);
      setManualPwd("");
      showToast("Password reset & notification sent to admin!");
    }, 1500);
  };

  return (
    <div style={{ fontFamily: "'DM Sans', 'Segoe UI', sans-serif", background: "#F0F4FA", minHeight: "100vh", color: "#1E293B" }}>
      {/* Toast */}
      {toast && (
        <div style={{ position:"fixed", top:20, right:20, background: toast.type==="success"?"#16A34A":"#DC2626", color:"#fff", padding:"12px 20px", borderRadius:10, zIndex:9999, fontSize:14, boxShadow:"0 4px 20px rgba(0,0,0,0.15)" }}>
          ✓ {toast.msg}
        </div>
      )}

      {/* Top Nav */}
      <div style={{ background:"#1B3A6B", color:"#fff", padding:"0 32px", display:"flex", alignItems:"center", height:58, gap:16, boxShadow:"0 2px 8px rgba(0,0,0,0.2)" }}>
        <span style={{ fontSize:20, fontWeight:700, letterSpacing:-0.5 }}>🏢 Society Manager</span>
        <span style={{ opacity:0.4, fontSize:18 }}>|</span>
        <span style={{ opacity:0.7, fontSize:13 }}>Super Admin Console</span>
        <div style={{ marginLeft:"auto", display:"flex", alignItems:"center", gap:10 }}>
          <div style={{ width:32, height:32, borderRadius:"50%", background:"#3B5998", display:"flex", alignItems:"center", justifyContent:"center", fontSize:13, fontWeight:700 }}>SA</div>
          <span style={{ fontSize:13, opacity:0.85 }}>Super Admin</span>
        </div>
      </div>

      <div style={{ display:"flex" }}>
        {/* Sidebar */}
        <div style={{ width:220, background:"#fff", minHeight:"calc(100vh - 58px)", borderRight:"1px solid #E2E8F0", padding:"20px 0" }}>
          {[
            { icon:"🏘️", label:"Societies", active:true },
            { icon:"👥", label:"Users" },
            { icon:"💳", label:"Subscriptions" },
            { icon:"📊", label:"Reports" },
            { icon:"⚙️", label:"Settings" },
          ].map(item => (
            <div key={item.label} style={{ padding:"10px 20px", display:"flex", alignItems:"center", gap:10, fontSize:14, fontWeight: item.active?600:400, color: item.active?"#1B3A6B":"#64748B", background: item.active?"#EEF2FF":"transparent", borderRight: item.active?"3px solid #1B3A6B":"3px solid transparent", cursor:"pointer" }}>
              <span>{item.icon}</span>{item.label}
            </div>
          ))}
        </div>

        {/* Main Content */}
        <div style={{ flex:1, padding:28 }}>

          {/* LIST VIEW */}
          {view === "list" && (
            <>
              {/* Header */}
              <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", marginBottom:20 }}>
                <div>
                  <div style={{ fontSize:22, fontWeight:700, color:"#1B3A6B" }}>Society Management</div>
                  <div style={{ fontSize:13, color:"#64748B", marginTop:2 }}>{societies.length} societies registered</div>
                </div>
                <button onClick={() => { setView("add"); setStep(0); }} style={{ background:"#1B3A6B", color:"#fff", border:"none", borderRadius:8, padding:"10px 20px", fontSize:14, fontWeight:600, cursor:"pointer", display:"flex", alignItems:"center", gap:8 }}>
                  + Register Society
                </button>
              </div>

              {/* Stats Cards */}
              <div style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:14, marginBottom:22 }}>
                {[
                  { label:"Total Societies", value: societies.length, color:"#1B3A6B", icon:"🏘️" },
                  { label:"Active", value: societies.filter(s=>s.status==="Active").length, color:"#16A34A", icon:"✅" },
                  { label:"On Trial", value: societies.filter(s=>s.status==="Trial").length, color:"#D97706", icon:"⏳" },
                  { label:"Suspended", value: societies.filter(s=>s.status==="Suspended").length, color:"#DC2626", icon:"🚫" },
                ].map(card => (
                  <div key={card.label} style={{ background:"#fff", borderRadius:12, padding:"16px 20px", boxShadow:"0 1px 4px rgba(0,0,0,0.06)", borderTop:`3px solid ${card.color}` }}>
                    <div style={{ fontSize:22 }}>{card.icon}</div>
                    <div style={{ fontSize:26, fontWeight:700, color:card.color, marginTop:4 }}>{card.value}</div>
                    <div style={{ fontSize:12, color:"#64748B", marginTop:2 }}>{card.label}</div>
                  </div>
                ))}
              </div>

              {/* Filters */}
              <div style={{ display:"flex", gap:12, marginBottom:16, alignItems:"center" }}>
                <input
                  placeholder="🔍  Search by society, city, admin..."
                  value={search} onChange={e => setSearch(e.target.value)}
                  style={{ flex:1, padding:"9px 14px", border:"1px solid #CBD5E1", borderRadius:8, fontSize:13, outline:"none", background:"#fff" }}
                />
                {["All","Active","Trial","Suspended"].map(s => (
                  <button key={s} onClick={() => setFilterStatus(s)} style={{ padding:"8px 14px", borderRadius:20, border:"1px solid", borderColor: filterStatus===s?"#1B3A6B":"#CBD5E1", background: filterStatus===s?"#1B3A6B":"#fff", color: filterStatus===s?"#fff":"#64748B", fontSize:12, fontWeight:500, cursor:"pointer" }}>
                    {s}
                  </button>
                ))}
              </div>

              {/* Table */}
              <div style={{ background:"#fff", borderRadius:12, boxShadow:"0 1px 4px rgba(0,0,0,0.07)", overflow:"hidden" }}>
                <table style={{ width:"100%", borderCollapse:"collapse", fontSize:13 }}>
                  <thead>
                    <tr style={{ background:"#F8FAFC", borderBottom:"2px solid #E2E8F0" }}>
                      {["#","Society Name","Location","Plan","Units","Admin","Status","Registered","Actions"].map(h => (
                        <th key={h} style={{ padding:"12px 14px", textAlign:"left", fontWeight:600, color:"#475569", fontSize:12, textTransform:"uppercase", letterSpacing:0.5 }}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map((s, i) => (
                      <tr key={s.id} style={{ borderBottom:"1px solid #F1F5F9", transition:"background 0.15s" }} onMouseEnter={e=>e.currentTarget.style.background="#F8FAFC"} onMouseLeave={e=>e.currentTarget.style.background="transparent"}>
                        <td style={{ padding:"12px 14px", color:"#94A3B8" }}>{i+1}</td>
                        <td style={{ padding:"12px 14px" }}>
                          <div style={{ fontWeight:600, color:"#1E293B" }}>{s.name}</div>
                          <div style={{ fontSize:11, color:"#94A3B8", marginTop:1 }}>{s.wings} Wing{s.wings>1?"s":""}</div>
                        </td>
                        <td style={{ padding:"12px 14px", color:"#475569" }}>{s.city}, {s.state}</td>
                        <td style={{ padding:"12px 14px" }}>
                          <span style={{ background: PLAN_COLORS[s.plan]+"18", color: PLAN_COLORS[s.plan], padding:"3px 10px", borderRadius:20, fontSize:11, fontWeight:700 }}>{s.plan}</span>
                        </td>
                        <td style={{ padding:"12px 14px", fontWeight:600 }}>{s.units}</td>
                        <td style={{ padding:"12px 14px" }}>
                          <div style={{ fontWeight:500 }}>{s.adminName}</div>
                          <div style={{ fontSize:11, color:"#94A3B8" }}>+91 {s.adminPhone}</div>
                        </td>
                        <td style={{ padding:"12px 14px" }}>
                          <span style={{ background: STATUS_BG[s.status], color: STATUS_COLORS[s.status], padding:"3px 10px", borderRadius:20, fontSize:11, fontWeight:600 }}>{s.status}</span>
                        </td>
                        <td style={{ padding:"12px 14px", color:"#64748B" }}>{s.registeredOn}</td>
                        <td style={{ padding:"12px 14px" }}>
                          <div style={{ display:"flex", gap:6 }}>
                            <button onClick={() => { setSelected(s); setView("detail"); }} style={{ padding:"5px 10px", border:"1px solid #CBD5E1", borderRadius:6, background:"#fff", color:"#1B3A6B", fontSize:11, cursor:"pointer", fontWeight:500 }}>View</button>
                            <button onClick={() => { setResetModal(s); setResetType("auto"); }} style={{ padding:"5px 10px", border:"1px solid #FCD34D", borderRadius:6, background:"#FFFBEB", color:"#B45309", fontSize:11, cursor:"pointer", fontWeight:500 }}>🔑 Reset</button>
                            <button onClick={() => handleToggleStatus(s.id)} style={{ padding:"5px 10px", border:`1px solid ${s.status==="Suspended"?"#BBF7D0":"#FECACA"}`, borderRadius:6, background: s.status==="Suspended"?"#F0FDF4":"#FFF5F5", color: s.status==="Suspended"?"#16A34A":"#DC2626", fontSize:11, cursor:"pointer", fontWeight:500 }}>
                              {s.status==="Suspended"?"Activate":"Suspend"}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {filtered.length === 0 && (
                  <div style={{ padding:40, textAlign:"center", color:"#94A3B8", fontSize:14 }}>No societies found</div>
                )}
              </div>
            </>
          )}

          {/* ADD SOCIETY - STEPPER */}
          {view === "add" && (
            <div style={{ maxWidth:720 }}>
              <div style={{ display:"flex", alignItems:"center", gap:12, marginBottom:24 }}>
                <button onClick={() => setView("list")} style={{ background:"none", border:"none", color:"#1B3A6B", cursor:"pointer", fontSize:20 }}>←</button>
                <div>
                  <div style={{ fontSize:20, fontWeight:700, color:"#1B3A6B" }}>Register New Society</div>
                  <div style={{ fontSize:13, color:"#64748B" }}>Step {step+1} of {STEPS.length}: {STEPS[step]}</div>
                </div>
              </div>

              {/* Step Indicator */}
              <div style={{ display:"flex", gap:0, marginBottom:28 }}>
                {STEPS.map((s, i) => (
                  <div key={i} style={{ flex:1, display:"flex", flexDirection:"column", alignItems:"center" }}>
                    <div style={{ display:"flex", alignItems:"center", width:"100%" }}>
                      {i>0 && <div style={{ flex:1, height:2, background: i<=step?"#1B3A6B":"#E2E8F0" }} />}
                      <div style={{ width:30, height:30, borderRadius:"50%", background: i<step?"#16A34A":i===step?"#1B3A6B":"#E2E8F0", color: i<=step?"#fff":"#94A3B8", display:"flex", alignItems:"center", justifyContent:"center", fontSize:13, fontWeight:700, flexShrink:0 }}>
                        {i<step?"✓":i+1}
                      </div>
                      {i<STEPS.length-1 && <div style={{ flex:1, height:2, background: i<step?"#1B3A6B":"#E2E8F0" }} />}
                    </div>
                    <div style={{ fontSize:11, color: i===step?"#1B3A6B":"#94A3B8", marginTop:5, fontWeight: i===step?600:400, textAlign:"center" }}>{s}</div>
                  </div>
                ))}
              </div>

              <div style={{ background:"#fff", borderRadius:12, padding:28, boxShadow:"0 1px 6px rgba(0,0,0,0.07)" }}>
                {step === 0 && (
                  <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:18 }}>
                    <div style={{ gridColumn:"1/-1" }}><Label>Society Name *</Label><Input value={form.name} onChange={v=>setForm({...form,name:v})} placeholder="e.g. Shree Residency CHS" /></div>
                    <div style={{ gridColumn:"1/-1" }}><Label>Address</Label><Input value={form.address} onChange={v=>setForm({...form,address:v})} placeholder="Street / Landmark" /></div>
                    <div><Label>City *</Label><Input value={form.city} onChange={v=>setForm({...form,city:v})} placeholder="Ahmedabad" /></div>
                    <div><Label>State *</Label><Input value={form.state} onChange={v=>setForm({...form,state:v})} placeholder="Gujarat" /></div>
                    <div><Label>PIN Code</Label><Input value={form.pin} onChange={v=>setForm({...form,pin:v})} placeholder="380001" /></div>
                    <div><Label>Society Type</Label>
                      <select value={form.type} onChange={e=>setForm({...form,type:e.target.value})} style={{ width:"100%", padding:"9px 12px", border:"1px solid #CBD5E1", borderRadius:7, fontSize:13, outline:"none" }}>
                        {["Apartment","Row House","Mixed"].map(t=><option key={t}>{t}</option>)}
                      </select>
                    </div>
                    <div><Label>No. of Wings</Label><Input value={form.wings} onChange={v=>setForm({...form,wings:v})} placeholder="e.g. 3" type="number" /></div>
                    <div><Label>Total Units *</Label><Input value={form.units} onChange={v=>setForm({...form,units:v})} placeholder="e.g. 120" type="number" /></div>
                  </div>
                )}
                {step === 1 && (
                  <div style={{ display:"grid", gap:18 }}>
                    <Label>Select Subscription Plan *</Label>
                    <div style={{ display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap:14 }}>
                      {[
                        { name:"Basic", price:"₹999/mo", features:["Upto 50 units","Visitor Mgmt","Notice Board"] },
                        { name:"Standard", price:"₹2,499/mo", features:["Upto 150 units","All Basic +","Payment Tracking"] },
                        { name:"Premium", price:"₹4,999/mo", features:["Unlimited units","All Standard +","Advanced Reports"] },
                      ].map(p => (
                        <div key={p.name} onClick={() => setForm({...form, plan:p.name})} style={{ border:`2px solid ${form.plan===p.name?PLAN_COLORS[p.name]:"#E2E8F0"}`, borderRadius:10, padding:16, cursor:"pointer", background: form.plan===p.name?PLAN_COLORS[p.name]+"0A":"#fff", transition:"all 0.2s" }}>
                          <div style={{ fontWeight:700, color: PLAN_COLORS[p.name], fontSize:15 }}>{p.name}</div>
                          <div style={{ fontSize:18, fontWeight:700, margin:"6px 0", color:"#1E293B" }}>{p.price}</div>
                          {p.features.map(f=><div key={f} style={{ fontSize:12, color:"#64748B", marginTop:3 }}>✓ {f}</div>)}
                        </div>
                      ))}
                    </div>
                    <div style={{ display:"flex", alignItems:"center", gap:12, marginTop:8 }}>
                      <input type="checkbox" id="trial" checked={form.trial} onChange={e=>setForm({...form,trial:e.target.checked})} />
                      <label htmlFor="trial" style={{ fontSize:13, color:"#475569" }}>Enable free trial period</label>
                      {form.trial && <Input value={form.trialDays} onChange={v=>setForm({...form,trialDays:v})} placeholder="Days" type="number" style={{ width:80 }} />}
                      {form.trial && <span style={{ fontSize:13, color:"#64748B" }}>days</span>}
                    </div>
                  </div>
                )}
                {step === 2 && (
                  <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:18 }}>
                    <div style={{ gridColumn:"1/-1", background:"#EEF6FF", border:"1px solid #BFDBFE", borderRadius:8, padding:"10px 14px", fontSize:13, color:"#1D4ED8" }}>
                      ℹ️ Login credentials will be auto-generated and sent to the admin via SMS & Email.
                    </div>
                    <div style={{ gridColumn:"1/-1" }}><Label>Admin Full Name *</Label><Input value={form.adminName} onChange={v=>setForm({...form,adminName:v})} placeholder="e.g. Rajesh Mehta" /></div>
                    <div><Label>Mobile Number *</Label><Input value={form.adminPhone} onChange={v=>setForm({...form,adminPhone:v})} placeholder="10-digit mobile" /></div>
                    <div><Label>Email Address</Label><Input value={form.adminEmail} onChange={v=>setForm({...form,adminEmail:v})} placeholder="admin@society.com" /></div>
                    <div><Label>Admin Role</Label>
                      <select value={form.adminRole} onChange={e=>setForm({...form,adminRole:e.target.value})} style={{ width:"100%", padding:"9px 12px", border:"1px solid #CBD5E1", borderRadius:7, fontSize:13, outline:"none" }}>
                        <option>Secretary</option><option>Pramukh</option>
                      </select>
                    </div>
                  </div>
                )}
                {step === 3 && (
                  <div style={{ display:"grid", gap:14 }}>
                    <div style={{ fontSize:15, fontWeight:600, color:"#1B3A6B", marginBottom:4 }}>Review Details Before Registering</div>
                    {[
                      ["Society Name", form.name], ["City / State", `${form.city}, ${form.state}`],
                      ["Society Type", form.type], ["Wings / Units", `${form.wings} wings · ${form.units} units`],
                      ["Plan", form.plan + (form.trial ? ` (${form.trialDays} days trial)` : "")],
                      ["Admin Name", form.adminName], ["Admin Phone", form.adminPhone],
                      ["Admin Email", form.adminEmail], ["Admin Role", form.adminRole],
                    ].map(([label, val]) => (
                      <div key={label} style={{ display:"flex", justifyContent:"space-between", borderBottom:"1px solid #F1F5F9", paddingBottom:10 }}>
                        <span style={{ fontSize:13, color:"#64748B" }}>{label}</span>
                        <span style={{ fontSize:13, fontWeight:500, color:"#1E293B" }}>{val || "—"}</span>
                      </div>
                    ))}
                  </div>
                )}

                <div style={{ display:"flex", justifyContent:"space-between", marginTop:24 }}>
                  <button onClick={() => step===0?setView("list"):setStep(step-1)} style={{ padding:"9px 20px", border:"1px solid #CBD5E1", borderRadius:8, background:"#fff", color:"#475569", fontSize:13, cursor:"pointer" }}>
                    {step===0?"Cancel":"← Back"}
                  </button>
                  <button onClick={() => step===STEPS.length-1?handleAddSociety():setStep(step+1)} style={{ padding:"9px 24px", border:"none", borderRadius:8, background:"#1B3A6B", color:"#fff", fontSize:13, fontWeight:600, cursor:"pointer" }}>
                    {step===STEPS.length-1?"✓ Register Society":"Next →"}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* DETAIL VIEW */}
          {view === "detail" && selected && (
            <div style={{ maxWidth:800 }}>
              <div style={{ display:"flex", alignItems:"center", gap:12, marginBottom:22 }}>
                <button onClick={() => setView("list")} style={{ background:"none", border:"none", color:"#1B3A6B", cursor:"pointer", fontSize:20 }}>←</button>
                <div style={{ fontSize:20, fontWeight:700, color:"#1B3A6B" }}>{selected.name}</div>
                <span style={{ background: STATUS_BG[selected.status], color: STATUS_COLORS[selected.status], padding:"4px 12px", borderRadius:20, fontSize:12, fontWeight:600 }}>{selected.status}</span>
              </div>
              <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:16 }}>
                <div style={{ background:"#fff", borderRadius:12, padding:20, boxShadow:"0 1px 4px rgba(0,0,0,0.06)" }}>
                  <div style={{ fontWeight:600, color:"#1B3A6B", marginBottom:14, fontSize:14 }}>🏘️ Society Info</div>
                  {[["City / State",`${selected.city}, ${selected.state}`],["Total Units",selected.units],["Wings",selected.wings],["Plan",selected.plan],["Registered",selected.registeredOn]].map(([k,v])=>(
                    <div key={k} style={{ display:"flex", justifyContent:"space-between", padding:"7px 0", borderBottom:"1px solid #F1F5F9", fontSize:13 }}>
                      <span style={{ color:"#64748B" }}>{k}</span><span style={{ fontWeight:500 }}>{v}</span>
                    </div>
                  ))}
                </div>
                <div style={{ background:"#fff", borderRadius:12, padding:20, boxShadow:"0 1px 4px rgba(0,0,0,0.06)" }}>
                  <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:14 }}>
                    <span style={{ fontWeight:600, color:"#1B3A6B", fontSize:14 }}>👤 Society Admin</span>
                    <button onClick={() => { setResetModal(selected); setResetType("auto"); }} style={{ padding:"5px 12px", border:"1px solid #FCD34D", borderRadius:6, background:"#FFFBEB", color:"#B45309", fontSize:11, cursor:"pointer", fontWeight:600 }}>🔑 Reset Password</button>
                  </div>
                  {[["Name",selected.adminName],["Phone","+91 "+selected.adminPhone],["Email",selected.adminEmail],["Role","Secretary"]].map(([k,v])=>(
                    <div key={k} style={{ display:"flex", justifyContent:"space-between", padding:"7px 0", borderBottom:"1px solid #F1F5F9", fontSize:13 }}>
                      <span style={{ color:"#64748B" }}>{k}</span><span style={{ fontWeight:500 }}>{v}</span>
                    </div>
                  ))}
                </div>
              </div>
              <div style={{ display:"grid", gridTemplateColumns:"repeat(4,1fr)", gap:12, marginTop:16 }}>
                {[["Total Units",selected.units,"🏠"],["Active Residents",Math.floor(selected.units*0.85),"👥"],["Open Complaints",4,"⚠️"],["Pending Approvals",2,"📋"]].map(([l,v,ic])=>(
                  <div key={l} style={{ background:"#fff", borderRadius:10, padding:"14px 16px", boxShadow:"0 1px 4px rgba(0,0,0,0.06)", textAlign:"center" }}>
                    <div style={{ fontSize:22 }}>{ic}</div>
                    <div style={{ fontSize:22, fontWeight:700, color:"#1B3A6B", marginTop:4 }}>{v}</div>
                    <div style={{ fontSize:11, color:"#64748B", marginTop:2 }}>{l}</div>
                  </div>
                ))}
              </div>
            </div>
          )}

        </div>
      </div>

      {/* RESET PASSWORD MODAL */}
      {resetModal && (
        <div style={{ position:"fixed", inset:0, background:"rgba(0,0,0,0.45)", display:"flex", alignItems:"center", justifyContent:"center", zIndex:1000 }}>
          <div style={{ background:"#fff", borderRadius:14, padding:28, width:420, boxShadow:"0 8px 40px rgba(0,0,0,0.2)" }}>
            {resetDone ? (
              <div style={{ textAlign:"center", padding:"20px 0" }}>
                <div style={{ fontSize:48, marginBottom:10 }}>✅</div>
                <div style={{ fontSize:16, fontWeight:700, color:"#16A34A" }}>Password Reset Successful!</div>
                <div style={{ fontSize:13, color:"#64748B", marginTop:6 }}>Notification sent to {resetModal.adminName} via SMS & Email.</div>
              </div>
            ) : (
              <>
                <div style={{ fontSize:17, fontWeight:700, color:"#1B3A6B", marginBottom:4 }}>🔑 Reset Admin Password</div>
                <div style={{ fontSize:13, color:"#64748B", marginBottom:20 }}>Society: <b>{resetModal.name}</b> · Admin: <b>{resetModal.adminName}</b></div>

                <div style={{ display:"flex", gap:10, marginBottom:20 }}>
                  {[["auto","Auto-generate & Send"],["manual","Set Manually"]].map(([val,label])=>(
                    <button key={val} onClick={()=>setResetType(val)} style={{ flex:1, padding:"9px 0", border:`2px solid ${resetType===val?"#1B3A6B":"#E2E8F0"}`, borderRadius:8, background: resetType===val?"#EEF2FF":"#fff", color: resetType===val?"#1B3A6B":"#64748B", fontSize:13, fontWeight:600, cursor:"pointer" }}>
                      {label}
                    </button>
                  ))}
                </div>

                {resetType === "auto" ? (
                  <div style={{ background:"#F0FDF4", border:"1px solid #BBF7D0", borderRadius:8, padding:"12px 14px", fontSize:13, color:"#166534", marginBottom:20 }}>
                    ✓ A new password will be auto-generated and sent to:<br />
                    <b>+91 {resetModal.adminPhone}</b> & <b>{resetModal.adminEmail}</b>
                  </div>
                ) : (
                  <div style={{ marginBottom:20 }}>
                    <Label>New Password</Label>
                    <Input value={manualPwd} onChange={v=>setManualPwd(v)} placeholder="Min 8 characters" type="password" />
                    <div style={{ fontSize:11, color:"#94A3B8", marginTop:5 }}>Admin will be notified via SMS that their password has been changed.</div>
                  </div>
                )}

                <div style={{ display:"flex", gap:10 }}>
                  <button onClick={()=>setResetModal(null)} style={{ flex:1, padding:"10px 0", border:"1px solid #E2E8F0", borderRadius:8, background:"#fff", color:"#64748B", fontSize:13, cursor:"pointer" }}>Cancel</button>
                  <button onClick={handleResetSubmit} style={{ flex:1, padding:"10px 0", border:"none", borderRadius:8, background:"#1B3A6B", color:"#fff", fontSize:13, fontWeight:600, cursor:"pointer" }}>Confirm Reset</button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// Helper components
function Label({ children }) {
  return <div style={{ fontSize:12, fontWeight:600, color:"#475569", marginBottom:5, textTransform:"uppercase", letterSpacing:0.4 }}>{children}</div>;
}
function Input({ value, onChange, placeholder, type="text", style={} }) {
  return <input type={type} value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder} style={{ width:"100%", padding:"9px 12px", border:"1px solid #CBD5E1", borderRadius:7, fontSize:13, outline:"none", boxSizing:"border-box", ...style }} />;
}
