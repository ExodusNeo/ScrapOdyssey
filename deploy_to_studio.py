import os
import json
from studio_client import StudioClient

def deploy():
    client = StudioClient()
    print("Deploying files to Roblox Studio session:", client.studio_id)

    files_to_deploy = [
        # (local_path, target_service, target_parent_path, script_name, class_name)
        ("src/shared/Modules/Types.luau", "ReplicatedStorage", "Modules", "Types", "ModuleScript"),
        ("src/shared/Modules/Config.luau", "ReplicatedStorage", "Modules", "Config", "ModuleScript"),
        ("src/shared/Modules/Remotes.luau", "ReplicatedStorage", "Modules", "Remotes", "ModuleScript"),
        
        ("src/server/Systems/DataService.luau", "ServerScriptService", "Systems", "DataService", "ModuleScript"),
        ("src/server/Systems/CurrencyService.luau", "ServerScriptService", "Systems", "CurrencyService", "ModuleScript"),
        ("src/server/Systems/ZoneService.luau", "ServerScriptService", "Systems", "ZoneService", "ModuleScript"),
        ("src/server/Systems/ActionService.luau", "ServerScriptService", "Systems", "ActionService", "ModuleScript"),
        
        ("src/server/Systems/ShopService.luau", "ServerScriptService", "Systems", "ShopService", "ModuleScript"),
        ("src/server/Systems/BackpackService.luau", "ServerScriptService", "Systems", "BackpackService", "ModuleScript"),
        ("src/server/Systems/PetService.luau", "ServerScriptService", "Systems", "PetService", "ModuleScript"),
        ("src/server/Systems/RebirthService.luau", "ServerScriptService", "Systems", "RebirthService", "ModuleScript"),
        ("src/server/Systems/QuestService.luau", "ServerScriptService", "Systems", "QuestService", "ModuleScript"),
        ("src/server/Systems/LeaderboardService.luau", "ServerScriptService", "Systems", "LeaderboardService", "ModuleScript"),
        ("src/server/Systems/MonetizationService.luau", "ServerScriptService", "Systems", "MonetizationService", "ModuleScript"),

        ("src/server/Main.server.luau", "ServerScriptService", "", "Main", "Script"),

        ("src/client/Controllers/HUDController.luau", "StarterPlayer/StarterPlayerScripts", "Controllers", "HUDController", "ModuleScript"),
        ("src/client/Controllers/ActionController.luau", "StarterPlayer/StarterPlayerScripts", "Controllers", "ActionController", "ModuleScript"),
        ("src/client/Controllers/MenuController.luau", "StarterPlayer/StarterPlayerScripts", "Controllers", "MenuController", "ModuleScript"),
        ("src/client/Controllers/ShopController.luau", "StarterPlayer/StarterPlayerScripts", "Controllers", "ShopController", "ModuleScript"),
        ("src/client/Controllers/PetController.luau", "StarterPlayer/StarterPlayerScripts", "Controllers", "PetController", "ModuleScript"),
        ("src/client/Controllers/RebirthController.luau", "StarterPlayer/StarterPlayerScripts", "Controllers", "RebirthController", "ModuleScript"),
        ("src/client/Controllers/QuestController.luau", "StarterPlayer/StarterPlayerScripts", "Controllers", "QuestController", "ModuleScript"),

        ("src/client/ClientMain.client.luau", "StarterPlayer/StarterPlayerScripts", "", "ClientMain", "LocalScript"),
    ]

    for local_path, service_path, sub_folder, script_name, class_name in files_to_deploy:
        full_path = os.path.join("D:\\RobloxProjects\\MyRobloxGame", local_path.replace("/", "\\"))
        if not os.path.exists(full_path):
            continue

        with open(full_path, "r", encoding="utf-8") as f:
            raw_code = f.read()

        json_wrapped = json.dumps({"source": raw_code})

        deploy_code = f"""
        local HttpService = game:GetService("HttpService")
        local payload = HttpService:JSONDecode([====[{json_wrapped}]====])
        local source = payload.source

        local serviceRoot
        if "{service_path}" == "StarterPlayer/StarterPlayerScripts" then
            serviceRoot = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
        else
            serviceRoot = game:GetService("{service_path}")
        end

        local parent = serviceRoot
        if "{sub_folder}" ~= "" then
            local current = parent
            for part in string.gmatch("{sub_folder}", "[^/]+") do
                local nextFolder = current:FindFirstChild(part)
                if not nextFolder then
                    nextFolder = Instance.new("Folder")
                    nextFolder.Name = part
                    nextFolder.Parent = current
                end
                current = nextFolder
            end
            parent = current
        end

        local scriptInst = parent:FindFirstChild("{script_name}")
        if not scriptInst or scriptInst.ClassName ~= "{class_name}" then
            if scriptInst then scriptInst:Destroy() end
            scriptInst = Instance.new("{class_name}")
            scriptInst.Name = "{script_name}"
            scriptInst.Parent = parent
        end

        scriptInst.Source = source
        return scriptInst.Name .. " deployed"
        """

        res = client.execute_luau(deploy_code)
        content = res.get('result', {}).get('content', [{}])[0].get('text', 'OK')
        print(f"[{script_name}] -> {content}")

    client.close()
    print("Deployment completed successfully!")

if __name__ == "__main__":
    deploy()
