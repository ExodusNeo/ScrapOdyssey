from studio_client import StudioClient

def rebuild():
    client = StudioClient()
    print("Rebuilding Central Hub in Studio...")
    code = """
    local SSS = game:GetService("ServerScriptService")
    local ZoneService = require(SSS.Systems.ZoneService)
    ZoneService.init()
    return "Hub, Lighting, Recycler, Egg Pods, and Zones successfully constructed in Studio!"
    """
    res = client.execute_luau(code)
    print("Result:", res)
    client.close()

if __name__ == "__main__":
    rebuild()
