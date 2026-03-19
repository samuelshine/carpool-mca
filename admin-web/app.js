function resolveApiBase() {
  const metaValue =
    document.querySelector('meta[name="uniride-api-base"]')?.content?.trim() || '';
  if (window.UNIRIDE_API_BASE) return window.UNIRIDE_API_BASE;
  if (metaValue) return metaValue;

  const storedValue = localStorage.getItem('uniride_admin_api_base');
  if (storedValue) return storedValue;

  if (window.location.protocol !== 'file:' && window.location.origin) {
    return window.location.origin;
  }

  return 'http://localhost:8000';
}

let API_BASE = resolveApiBase();
let refreshPromise = null;
let autoRefreshHandle = null;

const state = {
  accessToken: null,
  sessionToken: null,
  phone: null,
  currentSection: 'dashboard',
  currentVerificationType: 'identity',
  users: [],
  filteredUsers: [],
  sosAlerts: [],
  sosFilter: 'open',
  selectedSosAlertId: null,
  stats: null,
  selectedUserId: null,
};

window.addEventListener('load', () => {
  const savedAccessToken = localStorage.getItem('admin_access_token');
  if (savedAccessToken) {
    state.accessToken = savedAccessToken;
    showMainPage();
    refreshCurrentSection();
  } else {
    updateApiBaseLabel();
    probeBackendHealth();
  }
});

function $(id) {
  return document.getElementById(id);
}

function updateApiBaseLabel() {
  const el = $('api-base-label');
  if (el) {
    el.textContent = `API: ${API_BASE}`;
  }
}

function configureApiBase() {
  const nextValue = prompt('Enter the UniRide API base URL', API_BASE);
  if (nextValue == null) return;

  const normalized = nextValue.trim().replace(/\/+$/, '');
  if (!normalized) {
    localStorage.removeItem('uniride_admin_api_base');
    API_BASE = resolveApiBase();
  } else {
    localStorage.setItem('uniride_admin_api_base', normalized);
    API_BASE = normalized;
  }

  updateApiBaseLabel();
  probeBackendHealth();
  if (state.accessToken) {
    refreshCurrentSection();
  }
}

function apiHeaders(auth = false) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth && state.accessToken) {
    headers.Authorization = `Bearer ${state.accessToken}`;
  }
  return headers;
}

async function apiFetch(path, options = {}, auth = true, retryOnAuth = true) {
  try {
    const response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers: {
        ...apiHeaders(auth),
        ...(options.headers || {}),
      },
    });

    const text = await response.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch (_) {
      data = text;
    }

    if (auth && response.status === 401) {
      const refreshed = retryOnAuth ? await tryRefreshAdminSession() : false;
      if (refreshed) {
        return apiFetch(path, options, auth, false);
      }
      handleAuthExpired();
    }

    if (response.ok) {
      setConnectionState(true);
    }

    return {
      ok: response.ok,
      status: response.status,
      data,
    };
  } catch (_) {
    setConnectionState(false);
    return {
      ok: false,
      status: 0,
      data: { detail: 'Cannot connect to server' },
    };
  }
}

function setConnectionState(isConnected) {
  const pill = $('connection-pill');
  if (!pill) return;
  if (typeof isConnected === 'string') {
    pill.textContent =
      isConnected === 'degraded'
        ? 'Degraded'
        : isConnected === 'offline'
        ? 'Offline'
        : 'Connected';
    pill.className = `status-pill ${
      isConnected === 'degraded'
        ? 'status-pill-alert'
        : isConnected === 'offline'
        ? 'status-pill-offline'
        : 'status-pill-live'
    }`;
    return;
  }
  pill.textContent = isConnected ? 'Connected' : 'Offline';
  pill.className = `status-pill ${isConnected ? 'status-pill-live' : 'status-pill-offline'}`;
}

function handleAuthExpired() {
  localStorage.removeItem('admin_access_token');
  localStorage.removeItem('admin_refresh_token');
  state.accessToken = null;
  stopAutoRefresh();
  $('main-page').classList.add('hidden');
  $('main-page').classList.remove('active');
  $('login-page').classList.remove('hidden');
  $('login-page').classList.add('active');
  toast('Your admin session expired. Please sign in again.', true);
  probeBackendHealth();
}

async function tryRefreshAdminSession() {
  const refreshToken = localStorage.getItem('admin_refresh_token');
  if (!refreshToken) return false;
  if (refreshPromise) return refreshPromise;

  refreshPromise = (async () => {
    try {
      const response = await fetch(`${API_BASE}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
      const data = await response.json().catch(() => null);
      if (!response.ok || !data?.access_token) {
        return false;
      }

      state.accessToken = data.access_token;
      localStorage.setItem('admin_access_token', data.access_token);
      if (data.refresh_token) {
        localStorage.setItem('admin_refresh_token', data.refresh_token);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}

async function probeBackendHealth() {
  try {
    const response = await fetch(`${API_BASE}/health/ready`);
    if (response.ok) {
      setConnectionState('connected');
      return;
    }
    setConnectionState('degraded');
  } catch (_) {
    setConnectionState('offline');
  }
}

async function sendOtp() {
  const phoneInput = $('phone-input');
  const phoneValue = phoneInput.value.trim();
  if (phoneValue.length !== 10) {
    showError('phone-error', 'Enter a valid 10-digit number');
    return;
  }

  setLoading('send-otp-btn', true);
  const phone = `+91${phoneValue}`;
  const res = await apiFetch(
    '/auth/login/send-otp',
    {
      method: 'POST',
      body: JSON.stringify({ phone }),
    },
    false,
  );
  setLoading('send-otp-btn', false);

  if (res.ok && res.data?.session_token) {
    state.sessionToken = res.data.session_token;
    state.phone = phone;
    $('otp-phone-display').textContent = phone;
    $('step-phone').classList.add('hidden');
    $('step-otp').classList.remove('hidden');
    hideError('phone-error');
    setConnectionState(true);
    return;
  }

  showError('phone-error', res.data?.detail || 'Failed to send OTP');
}

async function verifyOtp() {
  const otp = $('otp-input').value.trim();
  if (otp.length !== 6) {
    showError('otp-error', 'Enter the 6-digit OTP');
    return;
  }

  setLoading('verify-otp-btn', true);
  const res = await apiFetch(
    '/auth/login/verify-otp',
    {
      method: 'POST',
      body: JSON.stringify({ session_token: state.sessionToken, otp }),
    },
    false,
  );
  setLoading('verify-otp-btn', false);

  if (!res.ok || !res.data?.access_token) {
    showError('otp-error', res.data?.detail || 'Invalid OTP');
    return;
  }

  state.accessToken = res.data.access_token;
  const meRes = await apiFetch('/users/me');
  if (!meRes.ok || !meRes.data?.is_admin) {
    state.accessToken = null;
    showError('otp-error', 'Access denied. This account is not an admin.');
    return;
  }

  localStorage.setItem('admin_access_token', state.accessToken);
  if (res.data.refresh_token) {
    localStorage.setItem('admin_refresh_token', res.data.refresh_token);
  }
  hideError('otp-error');
  setConnectionState(true);
  showMainPage();
  refreshCurrentSection();
}

function backToPhone() {
  $('step-otp').classList.add('hidden');
  $('step-phone').classList.remove('hidden');
}

function logout() {
  const refreshToken = localStorage.getItem('admin_refresh_token');
  if (refreshToken) {
    fetch(`${API_BASE}/auth/logout`, {
      method: 'POST',
      headers: apiHeaders(false),
      body: JSON.stringify({ refresh_token: refreshToken }),
    }).catch(() => {});
  }

  localStorage.removeItem('admin_access_token');
  localStorage.removeItem('admin_refresh_token');
  state.accessToken = null;
  stopAutoRefresh();
  $('main-page').classList.add('hidden');
  $('main-page').classList.remove('active');
  $('login-page').classList.remove('hidden');
  $('login-page').classList.add('active');
  probeBackendHealth();
}

function showMainPage() {
  $('login-page').classList.add('hidden');
  $('login-page').classList.remove('active');
  $('main-page').classList.remove('hidden');
  $('main-page').classList.add('active');
  updateApiBaseLabel();
  startAutoRefresh();
  probeBackendHealth();
}

function startAutoRefresh() {
  if (autoRefreshHandle) return;
  autoRefreshHandle = window.setInterval(() => {
    if (!state.accessToken || document.visibilityState !== 'visible') return;
    probeBackendHealth();
    refreshCurrentSection();
  }, 60000);
}

function stopAutoRefresh() {
  if (!autoRefreshHandle) return;
  window.clearInterval(autoRefreshHandle);
  autoRefreshHandle = null;
}

function closeUserDetail() {
  $('user-detail-modal').classList.add('hidden');
}

function closeUserDetailIfBackdrop(event) {
  if (event.target?.id === 'user-detail-modal' || event.target?.classList?.contains('modal-backdrop')) {
    closeUserDetail();
  }
}

async function openUserDetail(userId) {
  state.selectedUserId = userId;
  $('user-detail-modal').classList.remove('hidden');
  $('user-detail-content').innerHTML =
    '<div class="empty-state compact">Loading user detail...</div>';

  const res = await apiFetch(`/admin/users/${userId}`);
  if (!res.ok || !res.data) {
    $('user-detail-content').innerHTML =
      `<div class="empty-state compact">${esc(res.data?.detail || 'Unable to load user detail.')}</div>`;
    return;
  }

  renderUserDetail(res.data);
}

function showSection(name, element) {
  state.currentSection = name;

  document.querySelectorAll('.section').forEach((section) => {
    section.classList.remove('active');
    section.classList.add('hidden');
  });
  document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));

  $(`section-${name}`).classList.remove('hidden');
  $(`section-${name}`).classList.add('active');
  if (element) {
    element.classList.add('active');
  }

  const topbarTitle = {
    dashboard: 'Dashboard',
    users: 'Users',
    verifications: 'Verifications',
    sos: 'SOS Desk',
  };
  const topbarEyebrow = {
    dashboard: 'Operations overview',
    users: 'Account controls',
    verifications: 'Trust workflow',
    sos: 'Incident triage',
  };

  $('topbar-title').textContent = topbarTitle[name] || 'Admin';
  $('topbar-eyebrow').textContent = topbarEyebrow[name] || 'Admin console';

  refreshCurrentSection();
}

function refreshCurrentSection() {
  if (state.currentSection === 'dashboard') {
    loadDashboard();
    return;
  }
  if (state.currentSection === 'users') {
    loadUsers();
    return;
  }
  if (state.currentSection === 'verifications') {
    loadVerifications();
    return;
  }
  if (state.currentSection === 'sos') {
    loadSos();
  }
}

async function loadDashboard() {
  renderStatsLoading();
  renderDashboardQueueLoading();

  const [statsRes, openSosRes, identityRes, driverRes] = await Promise.all([
    apiFetch('/admin/stats'),
    apiFetch('/admin/sos?status=open&page_size=5'),
    apiFetch('/admin/verifications/identity/pending'),
    apiFetch('/admin/verifications/driver/pending'),
  ]);

  if (statsRes.ok) {
    setConnectionState(true);
    state.stats = statsRes.data;
    renderStats(statsRes.data);
    syncNavigationCounts(statsRes.data);
    renderSosStats(statsRes.data?.sos);
  } else {
    renderStatsError(statsRes.data?.detail || 'Unable to load dashboard stats');
    toast(statsRes.data?.detail || 'Unable to load dashboard stats', true);
  }

  renderDashboardQueues({
    openSos: openSosRes.ok && Array.isArray(openSosRes.data) ? openSosRes.data : [],
    identity: identityRes.ok && Array.isArray(identityRes.data) ? identityRes.data : [],
    driver: driverRes.ok && Array.isArray(driverRes.data) ? driverRes.data : [],
  });
}

function renderStatsLoading() {
  $('stats-grid').innerHTML = '<div class="stat-card loading">Loading dashboard...</div>';
}

function renderDashboardQueueLoading() {
  $('dashboard-verifications').innerHTML =
    '<div class="empty-state compact">Loading verification queue...</div>';
  $('dashboard-sos').innerHTML =
    '<div class="empty-state compact">Loading SOS incidents...</div>';
}

function renderStatsError(message) {
  $('stats-grid').innerHTML = `<div class="empty-state">${esc(message)}</div>`;
}

function renderStats(stats) {
  const pendingReviews =
    (stats?.verifications?.pending_identity || 0) +
    (stats?.verifications?.pending_driver || 0);
  const sos = stats?.sos || {};

  $('stats-grid').innerHTML = `
    <article class="stat-card">
      <div class="stat-eyebrow">Users</div>
      <div class="stat-value">${stats?.users?.total || 0}</div>
      <div class="stat-label">${stats?.users?.active || 0} active accounts</div>
    </article>
    <article class="stat-card">
      <div class="stat-eyebrow">Verified identities</div>
      <div class="stat-value">${stats?.users?.identity_verified || 0}</div>
      <div class="stat-label">Students cleared for trust checks</div>
    </article>
    <article class="stat-card">
      <div class="stat-eyebrow">Verified drivers</div>
      <div class="stat-value">${stats?.users?.driver_verified || 0}</div>
      <div class="stat-label">Drivers allowed to offer rides</div>
    </article>
    <article class="stat-card stat-card-strong">
      <div class="stat-eyebrow">Pending reviews</div>
      <div class="stat-value">${pendingReviews}</div>
      <div class="stat-label">${stats?.verifications?.pending_identity || 0} identity, ${stats?.verifications?.pending_driver || 0} driver</div>
    </article>
    <article class="stat-card">
      <div class="stat-eyebrow">Open rides</div>
      <div class="stat-value">${stats?.rides?.active_open || 0}</div>
      <div class="stat-label">Currently available for booking</div>
    </article>
    <article class="stat-card stat-card-alert">
      <div class="stat-eyebrow">Open SOS</div>
      <div class="stat-value">${sos.open || 0}</div>
      <div class="stat-label">${sos.resolved || 0} resolved, ${sos.closed || 0} closed</div>
    </article>
  `;
}

function renderSosStats(sos) {
  if (!sos) {
    $('sos-stats-grid').innerHTML = '<div class="stat-card loading">Loading SOS stats...</div>';
    return;
  }

  $('sos-stats-grid').innerHTML = `
    <article class="stat-card stat-card-alert">
      <div class="stat-eyebrow">Open alerts</div>
      <div class="stat-value">${sos.open || 0}</div>
      <div class="stat-label">Need active admin attention</div>
    </article>
    <article class="stat-card">
      <div class="stat-eyebrow">Resolved</div>
      <div class="stat-value">${sos.resolved || 0}</div>
      <div class="stat-label">Marked handled by admins</div>
    </article>
    <article class="stat-card">
      <div class="stat-eyebrow">Closed</div>
      <div class="stat-value">${sos.closed || 0}</div>
      <div class="stat-label">Dismissed or completed incidents</div>
    </article>
    <article class="stat-card">
      <div class="stat-eyebrow">Total triggered</div>
      <div class="stat-value">${sos.total_triggered || 0}</div>
      <div class="stat-label">Full historical volume</div>
    </article>
  `;
}

function renderDashboardQueues({ openSos, identity, driver }) {
  const verificationItems = [
    ...identity.map((item) => ({ ...item, type: 'Identity' })),
    ...driver.map((item) => ({ ...item, type: 'Driver' })),
  ]
    .sort((a, b) => new Date(a.submitted_at || 0) - new Date(b.submitted_at || 0))
    .slice(0, 6);

  $('dashboard-verifications').innerHTML = verificationItems.length
    ? verificationItems
        .map(
          (item) => `
            <div class="list-item">
              <div>
                <div class="list-title">${esc(item.full_name)}</div>
                <div class="list-meta">${item.type} review · ${esc(item.phone_number)}</div>
              </div>
              <div class="status-pill status-pill-muted">${timeAgo(item.submitted_at)}</div>
            </div>
          `,
        )
        .join('')
    : '<div class="empty-state compact">No pending verification reviews.</div>';

  $('dashboard-sos').innerHTML = openSos.length
    ? openSos
        .map(
          (alert) => `
            <button class="list-item list-item-button" onclick="openSosFromDashboard('${alert.alert_id}')">
              <div>
                <div class="list-title">${esc(alert.user_name)}</div>
                <div class="list-meta">${shortId(alert.ride_id)} · ${formatDate(alert.triggered_at)}</div>
              </div>
              <div class="status-pill ${statusPillClass(alert.status)}">${formatStatus(alert.status)}</div>
            </button>
          `,
        )
        .join('')
    : '<div class="empty-state compact">No open SOS alerts right now.</div>';
}

function syncNavigationCounts(stats) {
  const pendingReviews =
    (stats?.verifications?.pending_identity || 0) +
    (stats?.verifications?.pending_driver || 0);

  $('nav-open-sos').textContent = `${stats?.sos?.open || 0} open`;
  $('nav-users-count').textContent = `${stats?.users?.total || 0}`;
  $('nav-pending-verifications').textContent = `${pendingReviews} pending`;
  $('nav-sos-status').textContent =
    (stats?.sos?.open || 0) > 0 ? 'Immediate attention' : 'Stable';
}

async function loadUsers() {
  const tbody = $('users-tbody');
  tbody.innerHTML = '<tr><td colspan="7" class="loading-row">Loading users...</td></tr>';

  const res = await apiFetch('/admin/users?page_size=100');
  if (!res.ok) {
    tbody.innerHTML = `<tr><td colspan="7" class="error-row">${esc(res.data?.detail || 'Unable to load users')}</td></tr>`;
    return;
  }

  setConnectionState(true);
  state.users = Array.isArray(res.data) ? res.data : [];
  state.filteredUsers = [...state.users];
  renderUsers(state.filteredUsers);
}

function renderUsers(users) {
  const tbody = $('users-tbody');
  if (!users.length) {
    tbody.innerHTML = '<tr><td colspan="7" class="empty-row">No users found.</td></tr>';
    return;
  }

  tbody.innerHTML = users
    .map(
      (user) => `
        <tr>
          <td>
            <div class="table-title">${esc(user.full_name)}</div>
            <div class="table-sub">${shortId(user.user_id)}</div>
          </td>
          <td>${esc(user.phone_number)}</td>
          <td>${user.email ? esc(user.email) : '<span class="badge badge-muted">None</span>'}</td>
          <td>${user.is_identity_verified ? '<span class="badge badge-success">Verified</span>' : '<span class="badge badge-muted">Pending</span>'}</td>
          <td>${user.is_driver_verified ? '<span class="badge badge-primary">Verified</span>' : '<span class="badge badge-muted">No</span>'}</td>
          <td>${user.is_active ? '<span class="badge badge-success">Active</span>' : '<span class="badge badge-danger">Disabled</span>'}</td>
          <td>
            <div class="table-actions">
              <button class="btn-sm btn-primary-soft" onclick="openUserDetail('${user.user_id}')">Inspect</button>
              ${
                user.is_active
                  ? `<button class="btn-sm btn-danger" onclick="deactivateUser('${user.user_id}')">Deactivate</button>`
                  : `<button class="btn-sm btn-success" onclick="activateUser('${user.user_id}')">Activate</button>`
              }
            </div>
          </td>
        </tr>
      `,
    )
    .join('');
}

function filterUsers() {
  const query = $('user-search').value.trim().toLowerCase();
  if (!query) {
    renderUsers(state.users);
    return;
  }

  const filtered = state.users.filter((user) => {
    return (
      (user.full_name || '').toLowerCase().includes(query) ||
      (user.phone_number || '').includes(query) ||
      (user.email || '').toLowerCase().includes(query)
    );
  });
  renderUsers(filtered);
}

async function deactivateUser(userId) {
  if (!confirm('Deactivate this user account?')) return;

  const res = await apiFetch(`/admin/users/${userId}/deactivate`, {
    method: 'PUT',
    body: JSON.stringify({}),
  });
  if (res.ok) {
    toast('User deactivated');
    loadUsers();
    loadDashboard();
    return;
  }
  toast(res.data?.detail || 'Unable to deactivate user', true);
}

async function activateUser(userId) {
  const res = await apiFetch(`/admin/users/${userId}/activate`, {
    method: 'PUT',
    body: JSON.stringify({}),
  });
  if (res.ok) {
    toast('User reactivated');
    loadUsers();
    loadDashboard();
    return;
  }
  toast(res.data?.detail || 'Unable to activate user', true);
}

async function loadVerifications() {
  await fetchVerifications(state.currentVerificationType);
}

function switchTab(type, element) {
  document.querySelectorAll('.tab').forEach((tab) => tab.classList.remove('active'));
  if (element) {
    element.classList.add('active');
  }
  state.currentVerificationType = type;
  fetchVerifications(type);
}

async function fetchVerifications(type) {
  const container = $('verifications-list');
  container.innerHTML = '<div class="empty-state">Loading verification queue...</div>';

  const res = await apiFetch(`/admin/verifications/${type}/pending`);
  if (!res.ok) {
    container.innerHTML = `<div class="empty-state">${esc(res.data?.detail || 'Unable to load verifications')}</div>`;
    return;
  }

  const items = Array.isArray(res.data) ? res.data : [];
  if (!items.length) {
    container.innerHTML = `<div class="empty-state">No pending ${esc(type)} verifications.</div>`;
    return;
  }

  container.innerHTML = items
    .map(
      (item) => `
        <article class="verification-card">
          <div class="verification-head">
            <div class="verification-avatar">${esc((item.full_name || '?').charAt(0).toUpperCase())}</div>
            <div>
              <div class="verification-title">${esc(item.full_name)}</div>
              <div class="verification-meta">${esc(item.phone_number)}</div>
              ${item.email ? `<div class="verification-meta">${esc(item.email)}</div>` : ''}
            </div>
          </div>
          ${item.college_id_number ? `<div class="verification-field"><strong>College ID:</strong> ${esc(item.college_id_number)}</div>` : ''}
          ${item.license_number ? `<div class="verification-field"><strong>Licence number:</strong> ${esc(item.license_number)}</div>` : ''}
          ${
            item.document_url || item.license_document_url
              ? `<a class="doc-link" href="${esc(item.document_url || item.license_document_url)}" target="_blank" rel="noreferrer">View submitted document</a>`
              : '<div class="verification-field muted">No document link attached.</div>'
          }
            <div class="verification-foot">
              <div class="verification-meta">Submitted ${formatDate(item.submitted_at)}</div>
              <div class="verification-actions">
                <button class="btn-sm btn-primary-soft" onclick="openUserDetail('${item.user_id}')">Inspect user</button>
                <button class="btn-sm btn-success" onclick="approveVerification('${item.user_id}', '${type}')">Approve</button>
                <button class="btn-sm btn-danger" onclick="rejectVerification('${item.user_id}', '${type}')">Reject</button>
              </div>
          </div>
        </article>
      `,
    )
    .join('');
}

async function approveVerification(userId, type) {
  const notes = prompt('Approval note (optional):') || null;
  const res = await apiFetch(`/admin/verifications/${type}/${userId}/approve`, {
    method: 'PUT',
    body: JSON.stringify({ notes }),
  });
  if (res.ok) {
    toast(`${formatStatus(type)} verification approved`);
    fetchVerifications(type);
    loadDashboard();
    return;
  }
  toast(res.data?.detail || 'Unable to approve verification', true);
}

async function rejectVerification(userId, type) {
  const notes = prompt('Rejection reason (optional):') || null;
  const res = await apiFetch(`/admin/verifications/${type}/${userId}/reject`, {
    method: 'PUT',
    body: JSON.stringify({ notes }),
  });
  if (res.ok) {
    toast(`${formatStatus(type)} verification rejected`);
    fetchVerifications(type);
    loadDashboard();
    return;
  }
  toast(res.data?.detail || 'Unable to reject verification', true);
}

function setSosFilter(filter, element) {
  state.sosFilter = filter;
  document.querySelectorAll('.filter-chip').forEach((chip) => chip.classList.remove('active'));
  if (element) {
    element.classList.add('active');
  }
  const notes = {
    open: 'Showing unresolved incidents first.',
    resolved: 'Showing handled incidents with admin resolution notes.',
    closed: 'Showing closed incidents and dismissed cases.',
    all: 'Showing the complete SOS incident history.',
  };
  $('sos-toolbar-note').textContent = notes[filter] || '';
  loadSos();
}

async function loadSos() {
  $('sos-tbody').innerHTML =
    '<tr><td colspan="5" class="loading-row">Loading SOS incidents...</td></tr>';
  $('sos-detail').innerHTML =
    '<div class="empty-state compact">Loading incident details...</div>';

  const [statsRes, sosRes] = await Promise.all([
    apiFetch('/admin/stats'),
    apiFetch(`/admin/sos?status=${encodeURIComponent(state.sosFilter)}&page_size=100`),
  ]);

  if (statsRes.ok) {
    state.stats = statsRes.data;
    renderSosStats(statsRes.data?.sos);
    syncNavigationCounts(statsRes.data);
  }

  if (!sosRes.ok) {
    $('sos-tbody').innerHTML = `<tr><td colspan="5" class="error-row">${esc(sosRes.data?.detail || 'Unable to load SOS incidents')}</td></tr>`;
    $('sos-detail').innerHTML =
      '<div class="empty-state compact">Unable to load SOS details right now.</div>';
    return;
  }

  state.sosAlerts = Array.isArray(sosRes.data) ? sosRes.data : [];
  if (!state.sosAlerts.length) {
    state.selectedSosAlertId = null;
    $('sos-tbody').innerHTML =
      `<tr><td colspan="5" class="empty-row">No ${esc(state.sosFilter)} SOS incidents.</td></tr>`;
    $('sos-detail').innerHTML =
      '<div class="empty-state compact">No incident selected.</div>';
    return;
  }

  const stillExists = state.sosAlerts.some((alert) => alert.alert_id === state.selectedSosAlertId);
  if (!stillExists) {
    state.selectedSosAlertId = state.sosAlerts[0].alert_id;
  }

  renderSosTable();
  renderSelectedSosDetail();
}

function renderSosTable() {
  const tbody = $('sos-tbody');
  tbody.innerHTML = state.sosAlerts
    .map((alert) => {
      const isSelected = alert.alert_id === state.selectedSosAlertId;
      return `
        <tr class="${isSelected ? 'selected-row' : ''}" onclick="selectSosAlert('${alert.alert_id}')">
          <td><span class="badge ${statusBadgeClass(alert.status)}">${formatStatus(alert.status)}</span></td>
          <td>
            <div class="table-title">${esc(alert.user_name)}</div>
            <div class="table-sub">${esc(alert.user_phone_number)}</div>
          </td>
          <td>
            <div class="table-title">${shortId(alert.ride_id)}</div>
            <div class="table-sub">${esc(alert.start_address || 'Start')} to ${esc(alert.end_address || 'Destination')}</div>
          </td>
          <td>${formatDate(alert.triggered_at)}</td>
          <td>${renderLocationLink(alert)}</td>
        </tr>
      `;
    })
    .join('');
}

function selectSosAlert(alertId) {
  state.selectedSosAlertId = alertId;
  renderSosTable();
  renderSelectedSosDetail();
}

function openSosFromDashboard(alertId) {
  const navItem = document.querySelectorAll('.nav-item')[3];
  showSection('sos', navItem);
  state.sosFilter = 'open';
  document.querySelectorAll('.filter-chip').forEach((chip) => {
    chip.classList.toggle('active', chip.dataset.filter === 'open');
  });
  state.selectedSosAlertId = alertId;
  loadSos();
}

function renderSelectedSosDetail() {
  const alert = state.sosAlerts.find((item) => item.alert_id === state.selectedSosAlertId);
  if (!alert) {
    $('sos-detail').innerHTML =
      '<div class="empty-state compact">Select an SOS alert to view details.</div>';
    return;
  }

  const canAct = alert.status === 'open';
  $('sos-detail').innerHTML = `
    <div class="detail-header">
      <div>
        <div class="detail-eyebrow">Alert ${shortId(alert.alert_id)}</div>
        <h4>${esc(alert.user_name)}</h4>
        <p>${esc(alert.user_phone_number)}${alert.user_email ? ` · ${esc(alert.user_email)}` : ''}</p>
      </div>
      <span class="badge ${statusBadgeClass(alert.status)}">${formatStatus(alert.status)}</span>
    </div>

    <div class="detail-grid">
      <div class="detail-card">
        <div class="detail-label">Ride</div>
        <div class="detail-value">${shortId(alert.ride_id)}</div>
        <div class="detail-sub">${esc(alert.start_address || 'Start')} to ${esc(alert.end_address || 'Destination')}</div>
      </div>
      <div class="detail-card">
        <div class="detail-label">Ride state</div>
        <div class="detail-value">${formatStatus(alert.ride_status || 'unknown')}</div>
        <div class="detail-sub">${alert.ride_date ? formatDateOnly(alert.ride_date) : 'No ride date'}${alert.ride_time ? ` · ${esc(alert.ride_time)}` : ''}</div>
      </div>
      <div class="detail-card">
        <div class="detail-label">Triggered</div>
        <div class="detail-value">${formatDate(alert.triggered_at)}</div>
        <div class="detail-sub">${timeAgo(alert.triggered_at)}</div>
      </div>
      <div class="detail-card">
        <div class="detail-label">Location</div>
        <div class="detail-value">${alert.latitude != null && alert.longitude != null ? `${alert.latitude.toFixed(5)}, ${alert.longitude.toFixed(5)}` : 'Unknown'}</div>
        <div class="detail-sub">${renderLocationLink(alert)}</div>
      </div>
    </div>

    <div class="detail-block">
      <div class="detail-label">Resolution history</div>
      <div class="resolution-line">${alert.resolved_at ? `Updated ${formatDate(alert.resolved_at)}` : 'No admin action recorded yet.'}</div>
      <div class="resolution-line">${alert.resolved_by_name ? `Handled by ${esc(alert.resolved_by_name)}` : 'No assigned responder recorded.'}</div>
      <div class="resolution-line">${alert.resolution_notes ? esc(alert.resolution_notes) : 'No resolution notes yet.'}</div>
    </div>

    <div class="detail-block">
      <label class="detail-label" for="sos-resolution-notes">Admin notes</label>
      <textarea
        id="sos-resolution-notes"
        class="notes-input"
        placeholder="Document what happened, who responded, and why this alert is being resolved or closed."
        ${canAct ? '' : 'disabled'}
      >${alert.resolution_notes ? escTextarea(alert.resolution_notes) : ''}</textarea>
    </div>

    <div class="detail-actions">
      <button class="btn-sm btn-primary-soft" onclick="openUserDetail('${alert.user_id}')">Inspect user</button>
      <button class="btn-primary btn-inline" ${canAct ? '' : 'disabled'} onclick="updateSelectedSosStatus('resolved')">Resolve alert</button>
      <button class="btn-ghost btn-inline" ${canAct ? '' : 'disabled'} onclick="updateSelectedSosStatus('closed')">Close alert</button>
      ${!canAct ? '<div class="detail-hint">This incident is no longer open. Switch filters if you want to review other alerts.</div>' : ''}
    </div>
  `;
}

function renderUserDetail(detail) {
  const actionButton = detail.is_active
    ? `<button class="btn-sm btn-danger" onclick="toggleUserStateFromDetail('${detail.user_id}', false)">Deactivate user</button>`
    : `<button class="btn-sm btn-success" onclick="toggleUserStateFromDetail('${detail.user_id}', true)">Activate user</button>`;

  $('user-detail-content').innerHTML = `
    <div class="drawer-profile">
      <div>
        <div class="detail-eyebrow">Account</div>
        <h3>${esc(detail.full_name)}</h3>
        <p>${esc(detail.phone_number)}${detail.email ? ` · ${esc(detail.email)}` : ''}</p>
      </div>
      <div class="drawer-actions">
        <span class="badge ${detail.is_active ? 'badge-success' : 'badge-danger'}">${detail.is_active ? 'Active' : 'Disabled'}</span>
        <span class="badge ${detail.is_identity_verified ? 'badge-success' : 'badge-muted'}">Identity ${detail.is_identity_verified ? 'verified' : 'pending'}</span>
        <span class="badge ${detail.is_driver_verified ? 'badge-primary' : 'badge-muted'}">Driver ${detail.is_driver_verified ? 'verified' : 'not verified'}</span>
        ${actionButton}
      </div>
    </div>

    <div class="drawer-section">
      <div class="detail-label">Profile summary</div>
      <div class="detail-grid">
        <div class="detail-card">
          <div class="detail-label">Created</div>
          <div class="detail-value">${formatDate(detail.created_at)}</div>
          <div class="detail-sub">${detail.community ? esc(detail.community) : 'No community set'}</div>
        </div>
        <div class="detail-card">
          <div class="detail-label">Contact verification</div>
          <div class="detail-value">${detail.is_email_verified ? 'Email verified' : 'Email not verified'}</div>
          <div class="detail-sub">${detail.is_phone_verified ? 'Phone verified' : 'Phone not verified'}</div>
        </div>
        <div class="detail-card">
          <div class="detail-label">Activity overview</div>
          <div class="detail-value">${detail.activity_summary.driver_rides} driver rides</div>
          <div class="detail-sub">${detail.activity_summary.passenger_rides} passenger rides · ${detail.activity_summary.ride_requests} requests</div>
        </div>
        <div class="detail-card">
          <div class="detail-label">Safety and moderation</div>
          <div class="detail-value">${detail.activity_summary.reports_received} reports received</div>
          <div class="detail-sub">${detail.activity_summary.reports_filed} filed · ${detail.activity_summary.sos_triggered} SOS alerts</div>
        </div>
      </div>
    </div>

    <div class="drawer-section">
      <div class="detail-label">Verification records</div>
      <div class="drawer-two-column">
        ${renderVerificationDetailCard('Identity verification', detail.identity_verification)}
        ${renderVerificationDetailCard('Driver verification', detail.driver_verification)}
      </div>
    </div>

    <div class="drawer-section">
      <div class="detail-label">Vehicles</div>
      ${renderSimpleList(
        detail.vehicles,
        (vehicle) => `
          <div class="list-item">
            <div>
              <div class="list-title">${esc(vehicle.vehicle_number)}</div>
              <div class="list-meta">${formatStatus(vehicle.vehicle_type)}</div>
            </div>
            <div class="status-pill status-pill-muted">${formatDate(vehicle.created_at)}</div>
          </div>
        `,
        'No vehicles recorded for this user.',
      )}
    </div>

    <div class="drawer-section">
      <div class="detail-label">Recent rides and requests</div>
      ${renderSimpleList(
        detail.recent_rides,
        (ride) => `
          <div class="list-item">
            <div>
              <div class="list-title">${formatStatus(ride.role)} · ${esc(ride.start_address || 'Start')} to ${esc(ride.end_address || 'Destination')}</div>
              <div class="list-meta">${formatStatus(ride.status)}${ride.request_status ? ` · request ${formatStatus(ride.request_status)}` : ''}${ride.driver_name ? ` · driver ${esc(ride.driver_name)}` : ''}</div>
            </div>
            <div class="status-pill status-pill-muted">${formatDate(ride.activity_at)}</div>
          </div>
        `,
        'No recent ride activity found.',
      )}
    </div>

    <div class="drawer-section">
      <div class="detail-label">Reports</div>
      ${renderSimpleList(
        detail.recent_reports,
        (report) => `
          <div class="list-item">
            <div>
              <div class="list-title">${formatStatus(report.direction)} report involving ${esc(report.other_user_name)}</div>
              <div class="list-meta">${report.comment ? esc(report.comment) : 'No comment provided'}</div>
            </div>
            <div class="status-pill status-pill-muted">${formatDate(report.created_at)}</div>
          </div>
        `,
        'No moderation reports linked to this user.',
      )}
    </div>

    <div class="drawer-section">
      <div class="detail-label">SOS history</div>
      ${renderSimpleList(
        detail.recent_sos_alerts,
        (alert) => `
          <div class="list-item">
            <div>
              <div class="list-title">${formatStatus(alert.status)} alert for ${shortId(alert.ride_id)}</div>
              <div class="list-meta">${alert.resolution_notes ? esc(alert.resolution_notes) : 'No resolution notes recorded'}</div>
            </div>
            <div class="status-pill ${statusPillClass(alert.status)}">${formatDate(alert.triggered_at)}</div>
          </div>
        `,
        'No SOS alerts recorded for this user.',
      )}
    </div>
  `;
}

function renderVerificationDetailCard(title, detail) {
  if (!detail) {
    return `
      <div class="detail-block">
        <div class="detail-label">${esc(title)}</div>
        <div class="detail-value">No record</div>
        <div class="detail-sub">This user has not submitted this verification yet.</div>
      </div>
    `;
  }

  const documentLink =
    detail.document_url || detail.license_document_url
      ? `<a class="doc-link" href="${esc(detail.document_url || detail.license_document_url)}" target="_blank" rel="noreferrer">Open submitted document</a>`
      : '<span class="muted-inline">No document link attached</span>';

  const secondary =
    detail.college_id_number || detail.license_number
      ? esc(detail.college_id_number || detail.license_number)
      : 'No identifier attached';

  return `
    <div class="detail-block">
      <div class="detail-label">${esc(title)}</div>
      <div class="detail-value">${formatStatus(detail.status)}</div>
      <div class="detail-sub">${secondary}</div>
      <div class="detail-sub">${detail.reviewer_notes ? esc(detail.reviewer_notes) : 'No reviewer notes recorded'}</div>
      <div class="detail-sub">${detail.submitted_at ? `Submitted ${formatDate(detail.submitted_at)}` : 'No submission timestamp'}</div>
      <div class="detail-sub">${detail.reviewed_at ? `Reviewed ${formatDate(detail.reviewed_at)}` : 'Not reviewed yet'}</div>
      <div class="detail-sub">${documentLink}</div>
    </div>
  `;
}

function renderSimpleList(items, renderItem, emptyMessage) {
  if (!items || !items.length) {
    return `<div class="empty-state compact">${esc(emptyMessage)}</div>`;
  }
  return `<div class="list-stack">${items.map((item) => renderItem(item)).join('')}</div>`;
}

async function toggleUserStateFromDetail(userId, shouldActivate) {
  if (!shouldActivate && !confirm('Deactivate this user account?')) return;

  const path = shouldActivate
    ? `/admin/users/${userId}/activate`
    : `/admin/users/${userId}/deactivate`;
  const res = await apiFetch(path, {
    method: 'PUT',
    body: JSON.stringify({}),
  });

  if (!res.ok) {
    toast(res.data?.detail || 'Unable to update user status', true);
    return;
  }

  toast(shouldActivate ? 'User reactivated' : 'User deactivated');
  const refreshes = [openUserDetail(userId), loadDashboard()];
  if (state.currentSection === 'users') refreshes.push(loadUsers());
  if (state.currentSection === 'verifications') refreshes.push(loadVerifications());
  if (state.currentSection === 'sos') refreshes.push(loadSos());
  await Promise.all(refreshes);
}

async function updateSelectedSosStatus(nextStatus) {
  const alert = state.sosAlerts.find((item) => item.alert_id === state.selectedSosAlertId);
  if (!alert) return;

  const notes = $('sos-resolution-notes')?.value.trim() || null;
  const res = await apiFetch(`/admin/sos/${alert.alert_id}/status`, {
    method: 'PUT',
    body: JSON.stringify({ status: nextStatus, notes }),
  });

  if (!res.ok) {
    toast(res.data?.detail || `Unable to ${nextStatus} alert`, true);
    return;
  }

  toast(`SOS alert ${nextStatus}`);
  await Promise.all([loadDashboard(), loadSos()]);
}

function renderLocationLink(alert) {
  if (alert.latitude == null || alert.longitude == null) {
    return '<span class="muted-inline">Unknown</span>';
  }
  const url = `https://www.openstreetmap.org/?mlat=${alert.latitude}&mlon=${alert.longitude}&zoom=16`;
  return `<a class="map-link" href="${url}" target="_blank" rel="noreferrer">Open map</a>`;
}

function formatStatus(value) {
  return (value || 'unknown')
    .toString()
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function statusBadgeClass(status) {
  if (status === 'open') return 'badge-danger';
  if (status === 'resolved') return 'badge-success';
  if (status === 'closed') return 'badge-muted';
  return 'badge-primary';
}

function statusPillClass(status) {
  if (status === 'open') return 'status-pill-alert';
  if (status === 'resolved') return 'status-pill-live';
  return 'status-pill-muted';
}

function shortId(value) {
  if (!value) return '—';
  return `${value.substring(0, 8)}...`;
}

function esc(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escTextarea(value) {
  return esc(value).replace(/&#39;/g, "'");
}

function formatDate(value) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleString('en-IN', {
      dateStyle: 'medium',
      timeStyle: 'short',
    });
  } catch (_) {
    return value;
  }
}

function formatDateOnly(value) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleDateString('en-IN', {
      dateStyle: 'medium',
    });
  } catch (_) {
    return value;
  }
}

function timeAgo(value) {
  if (!value) return 'Unknown';
  const diffMs = Date.now() - new Date(value).getTime();
  const diffMinutes = Math.max(0, Math.round(diffMs / 60000));
  if (diffMinutes < 1) return 'Just now';
  if (diffMinutes < 60) return `${diffMinutes} min ago`;
  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours} hr ago`;
  const diffDays = Math.round(diffHours / 24);
  return `${diffDays} day ago`;
}

function showError(id, message) {
  const el = $(id);
  if (!el) return;
  el.textContent = message;
  el.classList.remove('hidden');
}

function hideError(id) {
  const el = $(id);
  if (!el) return;
  el.classList.add('hidden');
}

function setLoading(id, loading) {
  const el = $(id);
  if (!el) return;
  el.disabled = loading;
}

let toastTimer = null;
function toast(message, isError = false) {
  const el = $('toast');
  if (!el) return;
  el.textContent = message;
  el.className = `toast${isError ? ' toast-error' : ''}`;
  el.classList.remove('hidden');
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    el.classList.add('hidden');
  }, 3200);
}

setInterval(() => {
  const sosSection = $('section-sos');
  const dashboardSection = $('section-dashboard');
  if (sosSection?.classList.contains('active')) {
    loadSos();
  } else if (dashboardSection?.classList.contains('active')) {
    loadDashboard();
  }
}, 30000);
