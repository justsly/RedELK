select json_object('session_id', session_id, 'agentlogfile', '/empirelogs/'||name||'/agent.log','listener', listener, 'name', name, 'language', language, 'language_version', language_version, 'delay', delay, 'jitter', jitter, 'external_ip', external_ip, 'internal_ip', internal_ip, 'username', username, 'high_integrity', high_integrity, 'process_name', process_name, 'process_id', process_id, 'hostname', hostname, 'os_details', os_details, 'session_key', session_key, 'nonce', nonce, 'checkin_time', checkin_time, 'lastseen_time', lastseen_time, 'parent', parent, 'children', children, 'servers', servers, 'profile', profile, 'functions', functions, 'kill_date', kill_date, 'working_hours', working_hours, 'lost_limit', lost_limit, 'taskings', taskings, 'results', results) from agents where checkin_time > datetime(datetime('now', 'localtime'),'-2 minutes');
