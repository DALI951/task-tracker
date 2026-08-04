<?php
require_once __DIR__ . '/lib/config.php';
$projectId = TT_PROJECT_ID;
$authDomain = $projectId . '.firebaseapp.com';
$apiKey = TT_WEB_API_KEY;
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Task Tracker &mdash; Manager</title>
<style>
  :root { --bg:#0f1222; --card:#1a1f36; --line:#2a3050; --text:#e8eaf6; --muted:#8f97b8; --acc:#4f7cff; }
  * { box-sizing:border-box; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
         background:var(--bg); color:var(--text); min-height:100vh; display:flex; align-items:center; justify-content:center; }
  .wrap { width:min(440px,92vw); }
  h1 { font-size:1.25rem; margin:0 0 2px; }
  .sub { color:var(--muted); font-size:.85rem; margin:0 0 20px; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:16px; margin-bottom:14px; }
  .btn { width:100%; padding:14px; border:1px solid var(--line); border-radius:10px; background:#232a47;
         color:var(--text); font-size:1rem; cursor:pointer; text-align:center; margin-bottom:8px; }
  .btn:hover { background:#2b3360; }
  .btn.primary { background:var(--acc); border-color:var(--acc); font-weight:600; }
  .btn.primary:hover { filter:brightness(1.1); }
  label { display:block; font-size:.82rem; color:var(--muted); margin:12px 0 4px; }
  input { width:100%; padding:10px; border:1px solid var(--line); border-radius:8px; background:#12162a;
          color:var(--text); font-size:1rem; }
  .msg { font-size:.85rem; margin-top:10px; min-height:1.2em; }
  .ok { color:#4ade80; } .err { color:#f87171; }
  .small { font-size:.75rem; color:var(--muted); margin-top:8px; text-align:center; }
  a { color:var(--acc); }
  .hidden { display:none; }
</style>
</head>
<body>
<div class="wrap">
  <h1>Task Tracker</h1>
  <p class="sub">Manager tools &mdash; hosted on modali.powerpme.com</p>

  <div class="card">
    <button class="btn primary" id="btn-create">Create Account</button>
    <div id="create-form" class="hidden">
      <label>Passphrase</label>
      <input type="password" id="c-pass" autocomplete="off">
      <label>Manager name</label>
      <input type="text" id="c-name" autocomplete="off">
      <label>Email</label>
      <input type="email" id="c-email" autocomplete="off">
      <label>Password (min 6 characters)</label>
      <input type="password" id="c-pass2" autocomplete="new-password">
      <button class="btn" id="btn-create-submit" style="margin-top:14px">Create</button>
      <div class="msg" id="c-msg"></div>
    </div>
  </div>

  <div class="card">
    <button class="btn" id="btn-reset">Change Password</button>
    <div id="reset-form" class="hidden">
      <label>Email of the account</label>
      <input type="email" id="r-email" autocomplete="email">
      <button class="btn" id="btn-reset-submit" style="margin-top:14px">Send reset email</button>
      <div class="msg" id="r-msg"></div>
    </div>
  </div>

  <p class="small">Change Password sends a Firebase password-reset email to the address entered.</p>
</div>

<script src="https://www.gstatic.com/firebasejs/11.6.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/11.6.0/firebase-auth-compat.js"></script>
<script>
(function () {
  var cfg = { apiKey: "<?php echo $apiKey; ?>", authDomain: "<?php echo $authDomain; ?>", projectId: "<?php echo $projectId; ?>" };
  firebase.initializeApp(cfg);
  var auth = firebase.auth();

  var createCard = document.getElementById('btn-create');
  var createForm = document.getElementById('create-form');
  var resetCard = document.getElementById('btn-reset');
  var resetForm = document.getElementById('reset-form');

  createCard.addEventListener('click', function () {
    createForm.classList.toggle('hidden');
    resetForm.classList.add('hidden');
    document.getElementById('c-msg').className = 'msg';
    document.getElementById('c-msg').textContent = '';
  });
  resetCard.addEventListener('click', function () {
    resetForm.classList.toggle('hidden');
    createForm.classList.add('hidden');
    document.getElementById('r-msg').className = 'msg';
    document.getElementById('r-msg').textContent = '';
  });

  function setMsg(id, text, ok) {
    var el = document.getElementById(id);
    el.textContent = text;
    el.className = 'msg ' + (ok ? 'ok' : 'err');
  }

  document.getElementById('btn-create-submit').addEventListener('click', function () {
    var pass = document.getElementById('c-pass').value.trim();
    var name = document.getElementById('c-name').value.trim();
    var email = document.getElementById('c-email').value.trim();
    var pass2 = document.getElementById('c-pass2').value;
    if (!pass || !name || !email || !pass2) { setMsg('c-msg', 'Fill all fields.', false); return; }
    if (pass2.length < 6) { setMsg('c-msg', 'Password must be at least 6 characters.', false); return; }
    setMsg('c-msg', 'Creating account...', true);
    fetch('api/create-manager.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ passphrase: pass, name: name, email: email, password: pass2 })
    })
    .then(function (r) { return r.json().then(function (j) { return { status: r.status, j: j }; }); })
    .then(function (res) {
      if (res.j.ok) {
        setMsg('c-msg', 'Account created. The manager can now sign in with this email.', true);
        ['c-pass','c-name','c-email','c-pass2'].forEach(function (i) { document.getElementById(i).value = ''; });
      } else {
        setMsg('c-msg', res.j.error || 'Something went wrong.', false);
      }
    })
    .catch(function () { setMsg('c-msg', 'Network error, try again.', false); });
  });

  document.getElementById('btn-reset-submit').addEventListener('click', function () {
    var email = document.getElementById('r-email').value.trim();
    if (!email) { setMsg('r-msg', 'Enter the account email.', false); return; }
    setMsg('r-msg', 'Sending reset email...', true);
    auth.sendPasswordResetEmail(email)
      .then(function () { setMsg('r-msg', 'Reset email sent. Check the inbox.', true); document.getElementById('r-email').value = ''; })
      .catch(function (e) { setMsg('r-msg', e.code === 'auth/user-not-found' ? 'No account with that email.' : (e.message || 'Failed to send.'), false); });
  });
})();
</script>
</body>
</html>
