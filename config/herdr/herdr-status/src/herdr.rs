use serde_json::{Value, json};
use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::time::Duration;

/// herdr の CLI と同じ順で socket を決める。
pub fn socket_path() -> PathBuf {
    match std::env::var_os("HERDR_SOCKET_PATH") {
        Some(p) if !p.is_empty() => PathBuf::from(p),
        _ => crate::home().join(".config/herdr/herdr.sock"),
    }
}

/// 1接続1リクエスト。サーバは改行区切りの応答を1行書いて切断する。
pub fn request_at(path: &Path, method: &str, params: Value) -> Result<Value, String> {
    let mut stream = UnixStream::connect(path).map_err(|e| format!("{}: {e}", path.display()))?;
    // herdr が詰まってもタブ行の更新ごと止まらないようにする
    let timeout = Some(Duration::from_secs(1));
    stream.set_read_timeout(timeout).map_err(|e| e.to_string())?;
    stream.set_write_timeout(timeout).map_err(|e| e.to_string())?;
    let mut line = json!({"id": format!("herdr-status:{method}"), "method": method, "params": params}).to_string();
    line.push('\n');
    stream
        .write_all(line.as_bytes())
        .map_err(|e| format!("{method}: {e}"))?;
    let mut buf = Vec::new();
    let mut chunk = [0u8; 65536];
    while !buf.ends_with(b"\n") {
        let n = stream.read(&mut chunk).map_err(|e| format!("{method}: {e}"))?;
        if n == 0 {
            break;
        }
        buf.extend_from_slice(&chunk[..n]);
    }
    let resp: Value = serde_json::from_slice(&buf).map_err(|e| format!("{method}: {e}"))?;
    if let Some(err) = resp.get("error") {
        return Err(format!("{method}: {err}"));
    }
    resp.get("result")
        .cloned()
        .ok_or_else(|| format!("{method}: result がない"))
}

/// 問い合わせは常に実行し、書き込みは dry_run なら内容を stderr に出すだけにする。
pub struct Herdr {
    pub dry_run: bool,
    path: PathBuf,
}

impl Herdr {
    pub fn new(dry_run: bool) -> Self {
        Herdr {
            dry_run,
            path: socket_path(),
        }
    }

    pub fn query(&self, method: &str, params: Value) -> Result<Value, String> {
        request_at(&self.path, method, params)
    }

    pub fn send(&self, method: &str, params: Value) -> Result<Value, String> {
        if self.dry_run {
            eprintln!("{method} {params}");
            return Ok(Value::Null);
        }
        request_at(&self.path, method, params)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{BufRead, BufReader};
    use std::os::unix::net::UnixListener;
    use std::thread;

    fn serve(reply: &'static str) -> (PathBuf, thread::JoinHandle<String>) {
        let dir = crate::testutil::tempdir();
        let path = dir.join("herdr.sock");
        let listener = UnixListener::bind(&path).unwrap();
        let handle = thread::spawn(move || {
            let (stream, _) = listener.accept().unwrap();
            let mut reader = BufReader::new(stream.try_clone().unwrap());
            let mut line = String::new();
            reader.read_line(&mut line).unwrap();
            if !reply.is_empty() {
                (&stream).write_all(reply.as_bytes()).unwrap();
            } else {
                thread::sleep(Duration::from_millis(1500));
            }
            line
        });
        (path, handle)
    }

    #[test]
    fn sends_one_line_with_id_and_params() {
        let (path, handle) = serve("{\"id\":\"x\",\"result\":{\"type\":\"ok\"}}\n");
        let result = request_at(&path, "agent.list", json!({})).unwrap();
        assert_eq!(result, json!({"type": "ok"}));
        let sent: Value = serde_json::from_str(&handle.join().unwrap()).unwrap();
        assert_eq!(
            sent,
            json!({"id": "herdr-status:agent.list", "method": "agent.list", "params": {}})
        );
    }

    #[test]
    fn error_response_is_err() {
        let (path, _handle) = serve("{\"id\":\"x\",\"error\":{\"code\":\"bad\"}}\n");
        let err = request_at(&path, "pane.report_metadata", json!({})).unwrap_err();
        assert!(err.contains("bad"), "{err}");
    }

    #[test]
    fn silent_server_times_out() {
        let (path, _handle) = serve("");
        assert!(request_at(&path, "agent.list", json!({})).is_err());
    }
}
