from studio_client import StudioClient
import time
import json

client = StudioClient()
print("Connected Studio ID:", client.studio_id)

print("Starting Play Solo...")
start_res = client.call_tool("start_stop_play", {"is_start": True})
print("Start result:", start_res)

time.sleep(6)

print("Getting console output...")
console_res = client.call_tool("get_console_output", {})
content = console_res.get("result", {}).get("content", [{}])[0].get("text", "")
print("=== CONSOLE OUTPUT ===")
print(content[-3000:])
print("======================")

print("Stopping Play Solo...")
stop_res = client.call_tool("start_stop_play", {"is_start": False})
print("Stop result:", stop_res)

client.close()
