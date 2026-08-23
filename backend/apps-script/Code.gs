const FITNESS = Object.freeze({
  sourceFolderId: '1zO_jsb1U_SDkW2c7Qh5v3EuX6M023XSj',
  sourceSpreadsheetId: '1ZykWiFxfaMogyRiC-Gyv4CEytvC_KmCLr6ZbFd0WpN8',
  sourceCoachDocumentId: '12lJxa9vFAh-ahXp9kRIPu9LQZ8lnOkqBgenuWFSMGWE',
  schemaVersion: '1',
  timeZone: 'Asia/Shanghai',
  headers: {
    SchemaMeta: ['key', 'value', 'updated_at'],
    Profile: ['key', 'value', 'source', 'updated_at'],
    ExerciseConfig: ['exercise_id', 'primary_muscles', 'secondary_muscles', 'exclude_from_stats', 'increment', 'machine_increment', 'tracks_shoulder', 'tracks_nausea', 'tracks_lower_back', 'quick_priority', 'substitute_exercise_id', 'updated_at'],
    WorkoutSessions: ['session_id', 'local_date', 'timezone', 'plan_day', 'started_at', 'ended_at', 'duration_minutes', 'completed_sets', 'total_volume_kg', 'shoulder_pain', 'nausea', 'lower_back_discomfort', 'quick_mode', 'note', 'healthkit_uuid', 'updated_at'],
    WorkoutSets: ['set_id', 'session_id', 'exercise_id', 'set_index', 'weight_kg', 'reps', 'rir', 'completed', 'stopped_for_pain', 'completed_at', 'updated_at'],
    BodyMetrics: ['metric_id', 'local_date', 'timezone', 'source', 'weight_kg', 'waist_cm', 'sleep_hours', 'steps', 'active_energy_kcal', 'exercise_minutes', 'resting_heart_rate', 'body_fat_percent', 'skeletal_muscle_kg', 'fatigue_score', 'note', 'healthkit_source_ids', 'updated_at'],
    HealthWorkouts: ['workout_id', 'source_bundle_id', 'activity_type', 'started_at', 'ended_at', 'duration_minutes', 'active_energy_kcal', 'average_heart_rate', 'app_session_id', 'deleted', 'updated_at'],
    Meals: ['meal_id', 'local_date', 'timezone', 'meal_type', 'note', 'ai_status', 'updated_at'],
    MealPhotos: ['photo_id', 'meal_id', 'drive_file_id', 'drive_url', 'mime_type', 'created_at', 'updated_at'],
    ScheduleState: ['state_id', 'next_plan_day', 'planned_date', 'status', 'updated_at'],
    CoachNotes: ['note_id', 'local_date', 'type', 'content', 'priority', 'created_at', 'updated_at']
  }
});

function doGet() {
  return json_({ ok: true, service: 'fitness-log', schemaVersion: FITNESS.schemaVersion });
}

function doPost(e) {
  const requestId = Utilities.getUuid();
  try {
    const body = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    const id = body.requestId || requestId;
    verifyToken_(body.token);
    const ss = spreadsheet_();
    requireSchema_(ss);

    if (body.action === 'syncBatch') {
      const result = syncBatch_(ss, body.payload || {});
      return json_({ ok: true, requestId: id, data: result });
    }

    const previous = requestResult_(ss, id);
    if (previous) return json_({ ok: true, requestId: id, duplicate: true, serverRevision: previous });

    const result = dispatch_(ss, body.action, body.payload || {}, id);
    const revision = String(Date.now());
    rememberRequest_(ss, id, revision);
    return json_({ ok: true, requestId: id, serverRevision: revision, data: result || null });
  } catch (error) {
    return json_({
      ok: false,
      requestId,
      error: { code: error.name || 'Error', message: error.message || String(error) }
    });
  }
}

/** Run once from the Apps Script editor before deploying. */
function setupSchema() {
  const ss = spreadsheet_();
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    ensureSchema_(ss, true);
    return { spreadsheetId: ss.getId(), schemaVersion: FITNESS.schemaVersion };
  } finally {
    lock.releaseLock();
  }
}

/** Set API_TOKEN and optionally SPREADSHEET_ID/SOURCE_FOLDER_ID in Script Properties. */
function createPersonalToken() {
  const token = Utilities.getUuid() + Utilities.getUuid().replace(/-/g, '');
  PropertiesService.getScriptProperties().setProperty('API_TOKEN', token);
  return token;
}

function dispatch_(ss, action, payload, requestId) {
  switch (action) {
    case 'bootstrap': return bootstrap_(ss);
    case 'pullChanges': return bootstrap_(ss);
    case 'upsertBodyMetric': return upsertBodyMetric_(ss, payload);
    case 'upsertHealthDaily': return upsertBodyMetric_(ss, payload);
    case 'upsertHealthDailyBatch': return upsertBodyMetrics_(ss, payload);
    case 'upsertHealthWorkouts': return upsertHealthWorkouts_(ss, payload);
    case 'completeWorkout': return completeWorkout_(ss, payload, requestId);
    case 'upsertMeal': return upsertMeal_(ss, payload);
    case 'uploadMealPhoto': return uploadMealPhoto_(ss, payload);
    case 'rescheduleWorkout': return upsertSchedule_(ss, payload);
    case 'getProgress': return progress_(ss);
    default: throw new Error('Unsupported action: ' + action);
  }
}

function syncBatch_(ss, payload) {
  const items = Array.isArray(payload.items) ? payload.items : [];
  if (!items.length) return { results: [] };
  if (items.length > 25) throw new Error('syncBatch accepts at most 25 items');

  const ids = items.map(item => String(item.requestId || ''));
  if (ids.some(id => !id)) throw new Error('Every syncBatch item needs requestId');
  const previous = requestResults_(ss, ids);
  const results = [];
  const fresh = [];
  items.forEach(item => {
    const id = String(item.requestId);
    if (previous.has(id)) {
      results.push({ requestId: id, ok: true, duplicate: true });
    } else if (item.action === 'uploadMealPhoto' || item.action === 'syncBatch') {
      results.push({ requestId: id, ok: false, error: { code: 'UnsupportedAction', message: 'Action is not batchable: ' + item.action } });
    } else {
      fresh.push(item);
    }
  });

  const successful = [];
  const bodyItems = fresh.filter(item => item.action === 'upsertBodyMetric' || item.action === 'upsertHealthDaily');
  if (bodyItems.length) {
    try {
      upsertBodyMetrics_(ss, bodyItems.map(item => item.payload || {}));
      bodyItems.forEach(item => {
        successful.push(String(item.requestId));
        results.push({ requestId: String(item.requestId), ok: true });
      });
    } catch (error) {
      bodyItems.forEach(item => results.push({
        requestId: String(item.requestId), ok: false,
        error: { code: error.name || 'Error', message: error.message || String(error) }
      }));
    }
  }

  fresh.filter(item => item.action !== 'upsertBodyMetric' && item.action !== 'upsertHealthDaily').forEach(item => {
    const id = String(item.requestId);
    try {
      dispatch_(ss, item.action, item.payload || {}, id);
      successful.push(id);
      results.push({ requestId: id, ok: true });
    } catch (error) {
      results.push({
        requestId: id, ok: false,
        error: { code: error.name || 'Error', message: error.message || String(error) }
      });
    }
  });

  rememberRequests_(ss, successful, String(Date.now()));
  return { results };
}

function ensureSchema_(ss, createBackup) {
  const alreadyInitialized = !!ss.getSheetByName('SchemaMeta');
  if (createBackup && !alreadyInitialized) backupSpreadsheet_(ss);

  Object.keys(FITNESS.headers).forEach(name => ensureSheet_(ss, name, FITNESS.headers[name]));
  ss.setSpreadsheetTimeZone(FITNESS.timeZone);
  upsertByKey_(ss.getSheetByName('SchemaMeta'), 'key', {
    key: 'schema_version', value: FITNESS.schemaVersion, updated_at: isoNow_()
  });
  upsertByKey_(ss.getSheetByName('SchemaMeta'), 'key', {
    key: 'source_training_plan_tab', value: '训练计划', updated_at: isoNow_()
  });
  upsertByKey_(ss.getSheetByName('SchemaMeta'), 'key', {
    key: 'source_coach_document_id', value: FITNESS.sourceCoachDocumentId, updated_at: isoNow_()
  });

  seedProfile_(ss);
  seedExerciseConfig_(ss);
}

function requireSchema_(ss) {
  if (!ss.getSheetByName('SchemaMeta')) {
    throw new Error('Schema is not initialized; run setupSchema() once in Apps Script');
  }
}

function seedProfile_(ss) {
  const sheet = ss.getSheetByName('Profile');
  const source = 'Google Doc ' + FITNESS.sourceCoachDocumentId;
  const now = isoNow_();
  [
    ['sex', 'male'], ['age', '31'], ['height_cm', '180'],
    ['cycle', '12周身体重组型减脂'], ['goal', '腰腹明显变小、腹肌可见，同时保持偏壮和全身均衡增长'],
    ['weekly_training_target', '3'], ['shoulder_rule', '深部肩痛达到3/10或逐组加重时停止并不建议加重'],
    ['nausea_rule', '腿部训练恶心明显上升时延长休息并降低负荷或组数'],
    ['lower_back_rule', '记录下背两侧疲劳/不适，避免把锐痛或放射症状当作普通疲劳']
  ].forEach(item => upsertByKey_(sheet, 'key', { key: item[0], value: item[1], source, updated_at: now }));
}

function seedExerciseConfig_(ss) {
  const sheet = ss.getSheetByName('ExerciseConfig');
  const rows = [
    ['A-01','chest','triceps,frontDelts',false,2.5,false,true,false,false,1,''],
    ['A-02','quads','glutes',false,5,true,false,true,true,2,''],
    ['A-03','lats','upperBack,biceps',false,5,true,false,false,false,3,''],
    ['A-04','frontDelts','triceps,sideDelts',false,5,true,true,false,false,'',''],
    ['A-05','triceps','',false,5,true,false,false,false,'',''],
    ['A-06','abs','',false,5,true,false,false,false,'',''],
    ['B-01','upperBack','lats,rearDelts,biceps',false,5,true,false,false,true,1,''],
    ['B-02','glutes','hamstrings',false,5,true,false,true,true,2,''],
    ['B-03','chest','frontDelts,triceps',false,5,true,true,false,false,3,''],
    ['B-04','hamstrings','',false,5,true,false,false,false,'',''],
    ['B-05','rearDelts','upperBack',false,5,true,true,false,false,'',''],
    ['B-06','biceps','forearms',false,5,true,false,false,false,'',''],
    ['C-01','quads','glutes',false,5,true,false,true,true,1,''],
    ['C-02','lats','upperBack,biceps',false,5,true,false,false,false,2,''],
    ['C-03','chest','frontDelts,triceps',false,5,true,true,false,false,3,''],
    ['C-04','calves','',false,5,true,false,false,false,'',''],
    ['C-05','biceps','forearms',false,5,true,false,false,false,'',''],
    ['C-06','triceps','frontDelts',false,5,true,true,false,false,'',''],
    ['C-07','abs','',false,'',false,false,false,false,'','']
  ];
  rows.forEach(row => upsertByKey_(sheet, 'exercise_id', {
    exercise_id: row[0], primary_muscles: row[1], secondary_muscles: row[2],
    exclude_from_stats: row[3], increment: row[4], machine_increment: row[5],
    tracks_shoulder: row[6], tracks_nausea: row[7], tracks_lower_back: row[8],
    quick_priority: row[9], substitute_exercise_id: row[10], updated_at: isoNow_()
  }));
}

function bootstrap_(ss) {
  const names = ['训练计划'].concat(Object.keys(FITNESS.headers));
  const data = {};
  names.forEach(name => {
    const sheet = ss.getSheetByName(name);
    if (sheet) data[name] = sheetObjects_(sheet);
  });
  return {
    schemaVersion: FITNESS.schemaVersion,
    timeZone: FITNESS.timeZone,
    sourceSpreadsheetId: ss.getId(),
    sheets: data
  };
}

function upsertBodyMetric_(ss, payload) {
  const row = bodyMetricRow_(payload);
  upsertByKey_(ss.getSheetByName('BodyMetrics'), 'metric_id', row, true);
  return row;
}

function upsertBodyMetrics_(ss, payload) {
  const records = Array.isArray(payload) ? payload : [];
  const rows = records.map(bodyMetricRow_);
  upsertManyByKey_(ss.getSheetByName('BodyMetrics'), 'metric_id', rows, true);
  return { updated: rows.length };
}

function bodyMetricRow_(payload) {
  return {
    metric_id: payload.id,
    local_date: localDate_(payload.date),
    timezone: FITNESS.timeZone,
    source: payload.source,
    weight_kg: payload.weightKG,
    waist_cm: payload.waistCM,
    sleep_hours: payload.sleepHours,
    steps: payload.steps,
    active_energy_kcal: payload.activeEnergyKCal,
    exercise_minutes: payload.exerciseMinutes,
    resting_heart_rate: payload.restingHeartRate,
    body_fat_percent: payload.bodyFatPercent,
    skeletal_muscle_kg: payload.skeletalMuscleKG,
    fatigue_score: payload.fatigueScore,
    note: payload.note || '',
    healthkit_source_ids: JSON.stringify(payload.healthKitSourceIDs || []),
    updated_at: payload.updatedAt || isoNow_()
  };
}

function upsertHealthWorkouts_(ss, payload) {
  const records = Array.isArray(payload) ? payload : [];
  const sheet = ss.getSheetByName('HealthWorkouts');
  const rows = records.map(item => ({
    workout_id: item.id,
    source_bundle_id: item.sourceBundleID,
    activity_type: item.activityType,
    started_at: item.startedAt,
    ended_at: item.endedAt,
    duration_minutes: item.durationMinutes,
    active_energy_kcal: item.activeEnergyKCal,
    average_heart_rate: item.averageHeartRate,
    app_session_id: item.appSessionID,
    deleted: item.deleted,
    updated_at: item.updatedAt || isoNow_()
  }));
  upsertManyByKey_(sheet, 'workout_id', rows, true);
  return { updated: records.length };
}

function completeWorkout_(ss, payload, requestId) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const session = payload.session;
    const sets = session.sets || [];
    const completedSets = sets.filter(item => item.completed && !item.stoppedForPain);
    const volume = completedSets.reduce((total, item) => total + ((Number(item.weightKG) || 0) * (Number(item.reps) || 0)), 0);
    upsertByKey_(ss.getSheetByName('WorkoutSessions'), 'session_id', {
      session_id: session.id,
      local_date: localDate_(session.date),
      timezone: FITNESS.timeZone,
      plan_day: session.planDay,
      started_at: session.startedAt,
      ended_at: session.endedAt,
      duration_minutes: session.durationMinutes,
      completed_sets: completedSets.length,
      total_volume_kg: volume,
      shoulder_pain: session.shoulderPain,
      nausea: session.nausea,
      lower_back_discomfort: session.lowerBackDiscomfort,
      quick_mode: session.quickMode,
      note: session.note || '',
      healthkit_uuid: session.healthKitUUID || '',
      updated_at: isoNow_()
    });

    sets.forEach(item => upsertByKey_(ss.getSheetByName('WorkoutSets'), 'set_id', {
      set_id: item.id,
      session_id: session.id,
      exercise_id: item.exerciseID,
      set_index: item.setIndex,
      weight_kg: item.weightKG,
      reps: item.reps,
      rir: item.rir,
      completed: item.completed,
      stopped_for_pain: item.stoppedForPain,
      completed_at: item.completedAt || '',
      updated_at: isoNow_()
    }));
    upsertSchedule_(ss, payload.schedule);
    return { sessionId: session.id, setCount: sets.length };
  } finally {
    lock.releaseLock();
  }
}

function upsertMeal_(ss, payload) {
  const row = {
    meal_id: payload.id,
    local_date: localDate_(payload.date),
    timezone: FITNESS.timeZone,
    meal_type: payload.type,
    note: payload.note || '',
    ai_status: payload.aiStatus || 'pending',
    updated_at: payload.updatedAt || isoNow_()
  };
  upsertByKey_(ss.getSheetByName('Meals'), 'meal_id', row);
  return row;
}

function uploadMealPhoto_(ss, payload) {
  if (!payload.jpegBase64) throw new Error('Missing jpegBase64');
  const photoSheet = ss.getSheetByName('MealPhotos');
  const existing = sheetObjects_(photoSheet).find(row => String(row.photo_id) === String(payload.photoID));
  if (existing && existing.drive_file_id) return existing;
  const bytes = Utilities.base64Decode(payload.jpegBase64);
  const blob = Utilities.newBlob(bytes, 'image/jpeg', payload.photoID + '.jpg');
  const folder = mealFolder_();
  const file = folder.createFile(blob);
  const row = {
    photo_id: payload.photoID,
    meal_id: payload.mealID,
    drive_file_id: file.getId(),
    drive_url: file.getUrl(),
    mime_type: 'image/jpeg',
    created_at: isoNow_(),
    updated_at: isoNow_()
  };
  upsertByKey_(photoSheet, 'photo_id', row);
  return row;
}

function upsertSchedule_(ss, payload) {
  const row = {
    state_id: 'primary',
    next_plan_day: payload.nextPlanDay,
    planned_date: payload.plannedDate,
    status: payload.status,
    updated_at: payload.updatedAt || isoNow_()
  };
  upsertByKey_(ss.getSheetByName('ScheduleState'), 'state_id', row);
  return row;
}

function progress_(ss) {
  return {
    sessions: sheetObjects_(ss.getSheetByName('WorkoutSessions')),
    sets: sheetObjects_(ss.getSheetByName('WorkoutSets')),
    metrics: sheetObjects_(ss.getSheetByName('BodyMetrics')),
    healthWorkouts: sheetObjects_(ss.getSheetByName('HealthWorkouts'))
  };
}

function verifyToken_(token) {
  const expected = PropertiesService.getScriptProperties().getProperty('API_TOKEN');
  if (!expected) throw new Error('API_TOKEN is not configured');
  if (!token || token !== expected) throw new Error('Unauthorized');
}

function spreadsheet_() {
  const configured = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  return SpreadsheetApp.openById(configured || FITNESS.sourceSpreadsheetId);
}

function ensureSheet_(ss, name, headers) {
  const sheet = ss.getSheetByName(name) || ss.insertSheet(name);
  const current = sheet.getRange(1, 1, 1, headers.length).getValues()[0];
  if (sheet.getLastRow() === 0 || current.every(value => value === '')) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#EAF2FF');
  } else if (headers.some((header, index) => current[index] !== header)) {
    throw new Error('Header mismatch in ' + name + '; refusing destructive migration');
  }
  return sheet;
}

function upsertByKey_(sheet, keyHeader, object, patchNonNull) {
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const keyColumn = headers.indexOf(keyHeader);
  if (keyColumn < 0) throw new Error('Missing key header ' + keyHeader + ' in ' + sheet.getName());
  const rows = sheet.getLastRow() > 1 ? sheet.getRange(2, 1, sheet.getLastRow() - 1, headers.length).getValues() : [];
  const rowIndex = rows.findIndex(row => String(row[keyColumn]) === String(object[keyHeader]));
  const previous = rowIndex >= 0 ? rows[rowIndex] : Array(headers.length).fill('');
  const values = headers.map((header, index) => {
    const value = object[header];
    if (patchNonNull && (value === null || value === undefined || value === '')) return previous[index];
    return value === null || value === undefined ? '' : value;
  });
  if (rowIndex >= 0) sheet.getRange(rowIndex + 2, 1, 1, headers.length).setValues([values]);
  else sheet.appendRow(values);
}

function upsertManyByKey_(sheet, keyHeader, objects, patchNonNull) {
  if (!objects.length) return;
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const keyColumn = headers.indexOf(keyHeader);
  if (keyColumn < 0) throw new Error('Missing key header ' + keyHeader + ' in ' + sheet.getName());

  const rows = sheet.getLastRow() > 1
    ? sheet.getRange(2, 1, sheet.getLastRow() - 1, headers.length).getValues()
    : [];
  const indexes = new Map();
  rows.forEach((row, index) => indexes.set(String(row[keyColumn]), index));

  objects.forEach(object => {
    const key = String(object[keyHeader]);
    const rowIndex = indexes.has(key) ? indexes.get(key) : -1;
    const previous = rowIndex >= 0 ? rows[rowIndex] : Array(headers.length).fill('');
    const values = headers.map((header, index) => {
      const value = object[header];
      if (patchNonNull && (value === null || value === undefined || value === '')) return previous[index];
      return value === null || value === undefined ? '' : value;
    });
    if (rowIndex >= 0) rows[rowIndex] = values;
    else {
      indexes.set(key, rows.length);
      rows.push(values);
    }
  });

  if (rows.length) sheet.getRange(2, 1, rows.length, headers.length).setValues(rows);
}

function sheetObjects_(sheet) {
  if (!sheet || sheet.getLastRow() < 2) return [];
  const values = sheet.getDataRange().getValues();
  const headers = values.shift();
  return values.filter(row => row.some(value => value !== '')).map(row => {
    const object = {};
    headers.forEach((header, index) => object[header] = row[index]);
    return object;
  });
}

function backupSpreadsheet_(ss) {
  const file = DriveApp.getFileById(ss.getId());
  const parents = file.getParents();
  const parent = parents.hasNext() ? parents.next() : DriveApp.getRootFolder();
  const timestamp = Utilities.formatDate(new Date(), FITNESS.timeZone, 'yyyyMMdd-HHmmss');
  file.makeCopy(ss.getName() + '｜迁移前备份｜' + timestamp, parent);
}

function mealFolder_() {
  const properties = PropertiesService.getScriptProperties();
  const cached = properties.getProperty('MEAL_FOLDER_ID');
  if (cached) return DriveApp.getFolderById(cached);
  const sourceId = properties.getProperty('SOURCE_FOLDER_ID') || FITNESS.sourceFolderId;
  const source = DriveApp.getFolderById(sourceId);
  const folders = source.getFoldersByName('餐食照片｜FitnessApp');
  const folder = folders.hasNext() ? folders.next() : source.createFolder('餐食照片｜FitnessApp');
  properties.setProperty('MEAL_FOLDER_ID', folder.getId());
  return folder;
}

function rememberRequest_(ss, requestId, revision) {
  upsertByKey_(ss.getSheetByName('SchemaMeta'), 'key', {
    key: 'request:' + requestId, value: revision, updated_at: isoNow_()
  });
}

function rememberRequests_(ss, requestIds, revision) {
  if (!requestIds.length) return;
  const now = isoNow_();
  upsertManyByKey_(ss.getSheetByName('SchemaMeta'), 'key', requestIds.map(requestId => ({
    key: 'request:' + requestId, value: revision, updated_at: now
  })));
}

function requestResult_(ss, requestId) {
  const sheet = ss.getSheetByName('SchemaMeta');
  if (!sheet || sheet.getLastRow() < 2) return null;
  const values = sheet.getRange(2, 1, sheet.getLastRow() - 1, 2).getValues();
  const row = values.find(item => item[0] === 'request:' + requestId);
  return row ? row[1] : null;
}

function requestResults_(ss, requestIds) {
  const wanted = new Set(requestIds.map(id => 'request:' + id));
  const found = new Map();
  const sheet = ss.getSheetByName('SchemaMeta');
  if (!sheet || sheet.getLastRow() < 2) return found;
  const values = sheet.getRange(2, 1, sheet.getLastRow() - 1, 2).getValues();
  values.forEach(row => {
    if (wanted.has(String(row[0]))) found.set(String(row[0]).slice(8), row[1]);
  });
  return found;
}

function localDate_(value) {
  const date = value ? new Date(value) : new Date();
  return Utilities.formatDate(date, FITNESS.timeZone, 'yyyy-MM-dd');
}

function isoNow_() {
  return new Date().toISOString();
}

function json_(value) {
  return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON);
}
