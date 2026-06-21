// ============================================================
// MODHUB.JS - Main JavaScript for Cubic Battle 3 Mod Store
// Made by: 10 and 11 year old developers!
// ============================================================

// ============================================================
// GLOBAL VARIABLES
// ============================================================
let db = null;
let allMods = [];
let currentUser = null;
let isAdmin = false;
let selectedMod = null;
let downloadTimer = null;
let userVotes = {};

// ============================================================
// DATABASE FUNCTIONS
// ============================================================

function openDB() {
    return new Promise((resolve, reject) => {
        if (db) {
            resolve(db);
            return;
        }
        const request = indexedDB.open('ModHubFinal', 2);
        
        request.onupgradeneeded = function(e) {
            const database = e.target.result;
            if (!database.objectStoreNames.contains('users')) {
                database.createObjectStore('users', { keyPath: 'username' });
            }
            if (!database.objectStoreNames.contains('bans')) {
                database.createObjectStore('bans', { keyPath: 'username' });
            }
            if (!database.objectStoreNames.contains('mods')) {
                const ms = database.createObjectStore('mods', { keyPath: 'id', autoIncrement: true });
                ms.createIndex('createdAt', 'createdAt');
            }
            if (!database.objectStoreNames.contains('modVotes')) {
                database.createObjectStore('modVotes', { keyPath: 'id', autoIncrement: true });
            }
            if (!database.objectStoreNames.contains('install_queue')) {
                database.createObjectStore('install_queue', { keyPath: 'id', autoIncrement: true });
            }
        };
        
        request.onsuccess = function(e) {
            db = e.target.result;
            resolve(db);
        };
        
        request.onerror = function(e) {
            console.error('Database error:', e.target.error);
            reject(e.target.error);
        };
    });
}

async function dbPut(store, data) {
    await openDB();
    return new Promise((resolve) => {
        const tx = db.transaction(store, 'readwrite');
        const r = tx.objectStore(store).put(data);
        r.onsuccess = () => resolve(r.result);
        r.onerror = () => resolve(null);
    });
}

async function dbGet(store, key) {
    await openDB();
    return new Promise((resolve) => {
        const tx = db.transaction(store, 'readonly');
        const r = tx.objectStore(store).get(key);
        r.onsuccess = () => resolve(r.result);
        r.onerror = () => resolve(null);
    });
}

async function dbGetAll(store) {
    await openDB();
    return new Promise((resolve) => {
        const tx = db.transaction(store, 'readonly');
        const r = tx.objectStore(store).getAll();
        r.onsuccess = () => resolve(r.result || []);
        r.onerror = () => resolve([]);
    });
}

async function dbDelete(store, key) {
    await openDB();
    return new Promise((resolve) => {
        const tx = db.transaction(store, 'readwrite');
        tx.objectStore(store).delete(key);
        tx.oncomplete = () => resolve();
        tx.onerror = () => resolve();
    });
}

// ============================================================
// INITIALIZATION
// ============================================================

async function initApp() {
    try {
        await openDB();
        
        // Create admin if not exists
        const admin = await dbGet('users', 'Дима');
        if (!admin) {
            await dbPut('users', { 
                username: 'Дима', 
                password: 'ГыгЯРыг', 
                role: 'admin', 
                created: Date.now() 
            });
        }
        
        // Show auth modal
        document.getElementById('auth-modal').style.display = 'flex';
        document.getElementById('form-login').style.display = 'block';
        document.getElementById('form-register').style.display = 'none';
        document.getElementById('login-error').classList.add('hidden');
        document.getElementById('log-user').value = '';
        document.getElementById('log-pass').value = '';
        
        document.getElementById('main-lobby').innerHTML = '<p class="text-center text-[#ADB5BD] py-20">Login to see mods</p>';
        
        console.log('✅ App initialized!');
        console.log('🐺 Made by 10 and 11 year olds!');
        console.log('💩 Remember: KAKAK is love, KAKAK is life!');
        
    } catch (err) {
        console.error('❌ Init error:', err);
    }
}

// ============================================================
// AUTH FUNCTIONS
// ============================================================

function switchTab(tab) {
    document.getElementById('tab-login').className = 'tab-btn ' + (tab === 'login' ? 'active' : 'inactive');
    document.getElementById('tab-register').className = 'tab-btn ' + (tab === 'register' ? 'active' : 'inactive');
    document.getElementById('form-login').style.display = tab === 'login' ? 'block' : 'none';
    document.getElementById('form-register').style.display = tab === 'register' ? 'block' : 'none';
    document.getElementById('login-error').classList.add('hidden');
    document.getElementById('reg-error').classList.add('hidden');
    document.getElementById('reg-success').classList.add('hidden');
}

async function register() {
    const u = document.getElementById('reg-user').value.trim();
    const p = document.getElementById('reg-pass').value.trim();
    const p2 = document.getElementById('reg-pass2').value.trim();
    const err = document.getElementById('reg-error');
    const ok = document.getElementById('reg-success');
    
    err.classList.add('hidden');
    ok.classList.add('hidden');
    
    if (!u || !p) {
        err.textContent = 'Fill all fields';
        err.classList.remove('hidden');
        return;
    }
    if (u.length < 3) {
        err.textContent = 'Username min 3 characters';
        err.classList.remove('hidden');
        return;
    }
    if (p.length < 4) {
        err.textContent = 'Password min 4 characters';
        err.classList.remove('hidden');
        return;
    }
    if (p !== p2) {
        err.textContent = 'Passwords do not match';
        err.classList.remove('hidden');
        return;
    }
    
    try {
        const existing = await dbGet('users', u);
        if (existing) {
            err.textContent = 'User already exists';
            err.classList.remove('hidden');
            return;
        }
        
        await dbPut('users', { username: u, password: p, role: 'user', created: Date.now() });
        
        ok.textContent = '✅ Registration successful! Now login.';
        ok.classList.remove('hidden');
        document.getElementById('reg-user').value = '';
        document.getElementById('reg-pass').value = '';
        document.getElementById('reg-pass2').value = '';
        
        setTimeout(() => switchTab('login'), 1500);
    } catch (error) {
        console.error('Register error:', error);
        err.textContent = 'Error: ' + error.message;
        err.classList.remove('hidden');
    }
}

async function login() {
    const u = document.getElementById('log-user').value.trim();
    const p = document.getElementById('log-pass').value.trim();
    const err = document.getElementById('login-error');
    
    err.classList.add('hidden');
    
    if (!u || !p) {
        err.textContent = 'Fill all fields';
        err.classList.remove('hidden');
        return;
    }
    
    try {
        await openDB();
        
        const ban = await dbGet('bans', u);
        if (ban) {
            err.textContent = '🚫 Account banned';
            err.classList.remove('hidden');
            return;
        }
        
        const user = await dbGet('users', u);
        
        if (!user) {
            err.textContent = 'User not found';
            err.classList.remove('hidden');
            return;
        }
        
        if (user.password !== p) {
            err.textContent = 'Wrong password';
            err.classList.remove('hidden');
            return;
        }
        
        currentUser = user;
        isAdmin = (user.role === 'admin');
        
        document.getElementById('auth-modal').style.display = 'none';
        
        document.getElementById('header-user').textContent = (isAdmin ? '👑 ' : '👤 ') + u;
        document.getElementById('logout-btn').classList.remove('hidden');
        document.getElementById('upload-nav-btn').classList.remove('hidden');
        
        if (isAdmin) {
            document.getElementById('admin-menu').style.display = 'block';
        }
        
        const votes = await dbGetAll('modVotes');
        userVotes = {};
        votes.forEach(v => {
            if (v.username === u) {
                userVotes[v.modId] = v.vote;
            }
        });
        
        await loadMods();
        
        console.log('✅ Login successful:', u);
        showNotification('Welcome ' + u + '! 🎮', 'success');
        
    } catch (error) {
        console.error('Login error:', error);
        err.textContent = 'Error: ' + error.message;
        err.classList.remove('hidden');
    }
}

function doLogout() {
    currentUser = null;
    isAdmin = false;
    userVotes = {};
    allMods = [];
    selectedMod = null;
    
    document.getElementById('header-user').textContent = '';
    document.getElementById('logout-btn').classList.add('hidden');
    document.getElementById('upload-nav-btn').classList.add('hidden');
    document.getElementById('admin-menu').style.display = 'none';
    document.getElementById('admin-dropdown').style.display = 'none';
    
    const mp = document.getElementById('mod-page');
    if (mp.classList.contains('active')) {
        mp.classList.remove('active');
        mp.classList.add('invisible');
        document.body.style.overflow = '';
    }
    
    document.getElementById('main-lobby').innerHTML = '<p class="text-center text-[#ADB5BD] py-20">Login to see mods</p>';
    
    document.getElementById('auth-modal').style.display = 'flex';
    document.getElementById('form-login').style.display = 'block';
    document.getElementById('form-register').style.display = 'none';
    document.getElementById('login-error').classList.add('hidden');
    document.getElementById('log-user').value = '';
    document.getElementById('log-pass').value = '';
    
    console.log('Logged out');
    showNotification('Logged out! 👋', 'info');
}

// ============================================================
// MODS FUNCTIONS
// ============================================================

async function loadMods() {
    try {
        await openDB();
        allMods = await dbGetAll('mods');
        allMods.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
        renderLobby();
    } catch (err) {
        console.error('Load mods error:', err);
    }
}

function renderLobby() {
    const lobby = document.getElementById('main-lobby');
    
    if (!allMods || allMods.length === 0) {
        lobby.innerHTML = '<p class="text-center text-[#ADB5BD] py-20">No mods uploaded yet! 😢</p>';
        return;
    }
    
    let html = '<div class="mb-8"><div class="grid grid-cols-2 gap-x-3 gap-y-6">';
    
    allMods.forEach(mod => {
        const img = mod.img && mod.img.trim() ? mod.img : '';
        const likes = mod.likes || 0;
        const dislikes = mod.dislikes || 0;
        const total = likes + dislikes;
        const rating = total > 0 ? Math.round((dislikes / total) * 100) : 50;
        const isReplacement = mod.isGameReplacement || false;
        
        html += `
        <div class="relative active:scale-95 transition-transform cursor-pointer ${isReplacement ? 'full-mod' : ''}" onclick="openMod(${mod.id})">
            <div class="relative">
                ${img ? `<img src="${img}" class="mod-card-img" alt="${mod.title}" onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">` : ''}
                <div class="mod-card-placeholder" style="${img ? 'display:none' : 'display:flex'}">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#393B3D" stroke-width="1.5"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>
                </div>
                ${isReplacement ? '<span class="game-replacement-badge">🔄 GAME REPLACEMENT</span>' : ''}
                ${mod.likes && mod.likes > 50 ? '<span class="mod-badge">🔥 POPULAR</span>' : ''}
            </div>
            <p class="text-[13px] font-extrabold mt-1.5 leading-tight">${mod.title}</p>
            <div class="download-text mt-0.5">
                <svg width="12" height="12" fill="currentColor" viewBox="0 0 24 24"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>
                ${mod.downloads || 0} downloads
            </div>
            <div class="flex items-center gap-2 mt-1">
                <span class="text-[10px] text-green-400">👍 ${likes}</span>
                <div style="flex:1;height:6px;background:linear-gradient(to right,#22c55e,#eab308,#ef4444);border-radius:3px;position:relative">
                    <div style="position:absolute;top:-2px;left:${rating}%;width:3px;height:10px;background:#000;border:1px solid #fff;border-radius:2px;transform:translateX(-50%)"></div>
                </div>
                <span class="text-[10px] text-red-400">👎 ${dislikes}</span>
            </div>
            ${isReplacement ? '<div style="font-size:9px;color:#8B5CF6;margin-top:2px;">⚡ Full game replacement</div>' : ''}
        </div>`;
    });
    
    html += '</div></div>';
    lobby.innerHTML = html;
}

function openMod(id) {
    selectedMod = allMods.find(m => m.id === id);
    if (!selectedMod) return;
    
    const img = selectedMod.img && selectedMod.img.trim() ? selectedMod.img : '';
    const pi = document.getElementById('page-img');
    const ph = document.getElementById('page-img-placeholder');
    
    if (img) {
        pi.style.display = '';
        ph.style.display = 'none';
        pi.src = img;
    } else {
        pi.style.display = 'none';
        ph.style.display = 'flex';
    }
    
    document.getElementById('page-title').textContent = selectedMod.title;
    document.getElementById('page-desc').textContent = selectedMod.desc || 'No description';
    
    // Show/hide install button
    const installBtn = document.getElementById('install-btn');
    if (selectedMod.isGameReplacement) {
        installBtn.style.display = 'block';
        installBtn.textContent = '⚡ Install as Game Replacement';
        installBtn.className = 'btn-install';
    } else {
        installBtn.style.display = 'none';
    }
    
    // Badges
    const badges = document.getElementById('mod-badges');
    badges.innerHTML = '';
    if (selectedMod.isGameReplacement) {
        const badge = document.createElement('span');
        badge.className = 'mod-badge';
        badge.textContent = '🔄 GAME REPLACEMENT';
        badges.appendChild(badge);
    }
    
    const mp = document.getElementById('mod-page');
    mp.classList.remove('invisible');
    mp.classList.add('active');
    document.body.style.overflow = 'hidden';
    
    document.getElementById('dl-btn').classList.remove('hidden');
    document.getElementById('dl-btn-bottom').classList.remove('hidden');
    document.getElementById('install-progress-page').classList.remove('show');
    document.getElementById('install-progress-page').style.display = 'none';
    if (downloadTimer) clearInterval(downloadTimer);
    
    updateRatingBar();
    
    if (isAdmin) {
        document.getElementById('adm-downloads').value = selectedMod.downloads || 0;
        document.getElementById('adm-likes').value = selectedMod.likes || 0;
        document.getElementById('adm-dislikes').value = selectedMod.dislikes || 0;
    }
}

function closeMod() {
    document.getElementById('mod-page').classList.remove('active');
    setTimeout(() => {
        document.getElementById('mod-page').classList.add('invisible');
        document.body.style.overflow = '';
    }, 300);
}

function updateRatingBar() {
    if (!selectedMod) return;
    const l = selectedMod.likes || 0;
    const d = selectedMod.dislikes || 0;
    const pct = (l + d) > 0 ? Math.round((d / (l + d)) * 100) : 50;
    
    document.getElementById('rating-indicator').style.left = pct + '%';
    document.getElementById('like-count').textContent = l;
    document.getElementById('dislike-count').textContent = d;
    
    const v = userVotes[selectedMod.id];
    document.getElementById('like-btn').className = 'like-btn' + (v === 'like' ? ' active' : '');
    document.getElementById('dislike-btn').className = 'dislike-btn' + (v === 'dislike' ? ' active' : '');
}

// ============================================================
// LIKE / DISLIKE FUNCTIONS
// ============================================================

async function toggleLike() {
    if (!selectedMod || !currentUser) return;
    const cv = userVotes[selectedMod.id];
    
    if (cv === 'like') {
        selectedMod.likes = Math.max(0, (selectedMod.likes || 0) - 1);
        userVotes[selectedMod.id] = null;
        await removeVote(selectedMod.id);
    } else {
        if (cv === 'dislike') selectedMod.dislikes = Math.max(0, (selectedMod.dislikes || 0) - 1);
        selectedMod.likes = (selectedMod.likes || 0) + 1;
        userVotes[selectedMod.id] = 'like';
        await saveVote(selectedMod.id, 'like');
    }
    
    await dbPut('mods', selectedMod);
    updateRatingBar();
    await loadMods();
}

async function toggleDislike() {
    if (!selectedMod || !currentUser) return;
    const cv = userVotes[selectedMod.id];
    
    if (cv === 'dislike') {
        selectedMod.dislikes = Math.max(0, (selectedMod.dislikes || 0) - 1);
        userVotes[selectedMod.id] = null;
        await removeVote(selectedMod.id);
    } else {
        if (cv === 'like') selectedMod.likes = Math.max(0, (selectedMod.likes || 0) - 1);
        selectedMod.dislikes = (selectedMod.dislikes || 0) + 1;
        userVotes[selectedMod.id] = 'dislike';
        await saveVote(selectedMod.id, 'dislike');
    }
    
    await dbPut('mods', selectedMod);
    updateRatingBar();
    await loadMods();
}

async function saveVote(modId, vote) {
    const votes = await dbGetAll('modVotes');
    const ex = votes.find(v => v.modId === modId && v.username === currentUser.username);
    if (ex) { ex.vote = vote; await dbPut('modVotes', ex); }
    else await dbPut('modVotes', { modId, username: currentUser.username, vote });
}

async function removeVote(modId) {
    const votes = await dbGetAll('modVotes');
    const ex = votes.find(v => v.modId === modId && v.username === currentUser.username);
    if (ex) await dbDelete('modVotes', ex.id);
}

// ============================================================
// DOWNLOAD FUNCTIONS
// ============================================================

function startDownload() {
    if (!selectedMod || !selectedMod.zipData) return;
    
    const btn = document.getElementById('dl-btn');
    const prog = document.getElementById('install-progress-page');
    const bar = document.getElementById('progress-fill-page');
    const text = document.getElementById('progress-text-page');
    
    btn.classList.add('hidden');
    document.getElementById('dl-btn-bottom').classList.add('hidden');
    prog.style.display = 'block';
    prog.classList.add('show');
    bar.style.width = '0%';
    text.textContent = 'Downloading...';
    
    selectedMod.downloads = (selectedMod.downloads || 0) + 1;
    dbPut('mods', selectedMod);
    
    let w = 0;
    if (downloadTimer) clearInterval(downloadTimer);
    downloadTimer = setInterval(() => {
        w += Mat
