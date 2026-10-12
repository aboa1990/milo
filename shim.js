/* Replaces claude.ai's built-in database, sign-in and downloads with Supabase + the browser.
   The app code calls window.claude.use('db' | 'user' | 'downloads'). */
(function () {
  var cfg = window.APP_CONFIG || {};
  if (!window.supabase || !cfg.SUPABASE_URL || /YOUR-PROJECT/.test(cfg.SUPABASE_URL)) {
    console.error('Supabase is not configured. Edit config.js.');
    window.claude = { use: async function () { return null; } };
    return;
  }
  var sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
  var ready = (async function () {
    var s = await sb.auth.getSession();
    if (!s.data.session) {
      var r = await sb.auth.signInAnonymously();
      if (r.error) console.error('Anonymous sign-in failed. Turn on "Allow anonymous sign-ins" in Supabase.', r.error);
    }
  })();

  function err(e) {
    var denied = e && (e.code === '42501' || /row-level security|permission|only an admin/i.test(e.message || ''));
    var x = new Error(e && e.message ? e.message : 'Request failed');
    x.code = denied ? 'not_granted' : (e && e.code) || 'error';
    return x;
  }
  async function rows(c) {
    var r = await sb.from('docs').select('id,data').eq('collection', c);
    if (r.error) throw err(r.error);
    return r.data || [];
  }
  function watch(c, run) {
    run();
    sb.channel('w-' + c + '-' + Math.random().toString(36).slice(2))
      .on('postgres_changes', { event: '*', schema: 'public', table: 'docs', filter: 'collection=eq.' + c }, run)
      .subscribe();
  }
  function docApi(c, id) {
    return {
      async set(d) { var r = await sb.from('docs').upsert({ collection: c, id: id, data: d }); if (r.error) throw err(r.error); },
      async update(d) {
        var g = await sb.from('docs').select('data').eq('collection', c).eq('id', id).single();
        if (g.error) throw err(g.error);
        var r = await sb.from('docs').update({ data: Object.assign({}, g.data.data, d) }).eq('collection', c).eq('id', id);
        if (r.error) throw err(r.error);
      },
      async delete() { var r = await sb.from('docs').delete().eq('collection', c).eq('id', id); if (r.error) throw err(r.error); },
      onSnapshot(cb) {
        watch(c, async function () {
          try { var all = await rows(c), row = all.find(function (x) { return x.id === id; });
            cb({ exists: !!row, data: function () { return row ? row.data : {}; } }); } catch (e) { console.error(e); }
        });
      }
    };
  }
  function colApi(c) {
    return {
      doc: function (id) { return docApi(c, id); },
      onSnapshot(cb) {
        watch(c, async function () {
          try { var all = await rows(c);
            cb({ docs: all.map(function (r) { return { id: r.id, data: function () { return r.data; } }; }) }); } catch (e) { console.error(e); }
        });
      }
    };
  }
  window.claude = {
    use: async function (name) {
      await ready;
      if (name === 'db') return { collection: colApi, doc: function (p) { var a = p.split('/'); return docApi(a[0], a[1]); } };
      if (name === 'user') {
        var u = (await sb.auth.getUser()).data.user, admin = false;
        if (u && u.email) { var r = await sb.from('admins').select('email').limit(1); admin = !!(r.data && r.data.length); }
        window.__isAdmin = admin; window.__email = u && u.email;
        return { isOwner: async function () { return admin; }, canEdit: async function () { return admin; }, id: async function () { return u ? u.id : ''; } };
      }
      if (name === 'downloads') return {
        save: async function (o) {
          var b = o.data instanceof Blob ? o.data : new Blob([o.data], { type: /\.html$/.test(o.filename) ? 'text/html' : 'text/plain' });
          var a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = o.filename;
          document.body.appendChild(a); a.click(); a.remove(); setTimeout(function () { URL.revokeObjectURL(a.href); }, 1500);
        }
      };
      return null;
    }
  };

  // Small admin sign-in link at the bottom of the page (email magic link).
  window.addEventListener('DOMContentLoaded', async function () {
    await ready; await window.claude.use('user');
    var box = document.createElement('div');
    box.style.cssText = 'text-align:center;margin:8px 0 28px;font:12px system-ui,sans-serif;color:#667a82';
    var a = document.createElement('a'); a.href = '#'; a.style.color = '#0a7f8f';
    if (window.__isAdmin) {
      a.textContent = 'Admin (' + window.__email + ') · Sign out';
      a.onclick = async function (e) { e.preventDefault(); await sb.auth.signOut(); location.reload(); };
    } else {
      a.textContent = 'Admin login';
      a.onclick = async function (e) {
        e.preventDefault();
        var email = prompt('Admin email address:'); if (!email) return;
        var r = await sb.auth.signInWithOtp({ email: email.trim(), options: { emailRedirectTo: location.origin } });
        alert(r.error ? 'Could not send the link: ' + r.error.message : 'Check your email and open the sign-in link.');
      };
    }
    box.appendChild(a); document.body.appendChild(box);
  });
})();
