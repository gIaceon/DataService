-- This assumes the ProfileService module is in this script
-- If you dont have it grab it here: https://devforum.roblox.com/t/save-your-player-data-with-profileservice-datastore-module/667805

-- DataService

-- ProfileService wrapper and Data Cointainer
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Knit = require(game:GetService("ReplicatedStorage"):FindFirstChild('Knit', true));

-- If this doesn't work try and find any module named "signal" in your replicatedstorage
local Signal = require(ReplicatedStorage:FindFirstChild("signal", true));

local ProfileService = require(script:WaitForChild("ProfileService"));

local DataService = Knit.CreateService{
	Name = 'DataService';

	cached_Profiles = {}; -- {[Player] = Profile}
	
	DataServiceModule = ProfileService;
	Data_Version = 'v1'; -- Change this whenever you make major changes to your data
	DataLoaded = {};
};

local function OnIssueSignalRecieved(ErrorMessage, ProfileStoreName, ProfileKey)
	warn('[DataService] ProfileService issue:', ErrorMessage);
end;

local function OnCriticalStateSignalRecieved(IsCritical)
	warn('[DataService] ProfileService issue: DataStore issues are now',IsCritical and 'critical.' or 'okay.')
end;

local function PlayerDataLoaded(Player)
	local PlayerDataProfile = DataService.cached_Profiles[Player];
	PlayerDataProfile:Reconcile();

	local Meta = DataService:FetchProfileMetaData(PlayerDataProfile);
	
	if (not PlayerDataProfile:GetMetaTag('Data_Version')) then
		DataService:SetMetaTagOfProfile(PlayerDataProfile, 'Data_Version', DataService.Data_Version);
	end;
	
	if (PlayerDataProfile:GetMetaTag('Data_Version') ~= DataService.Data_Version) then
		-- Convert any data here
	end;
	
	task.spawn(function()
		repeat
			
			task.wait();
			
			local PlayerDataProfile = DataService.cached_Profiles[Player];
			
			if (PlayerDataProfile ~= nil) then
				--[[
					Update anything like leaderstats here
				]]
			else
				-- Data no longer exists
				break;
			end;
			
		until false;
	end);
end;

local function PlayerAdded(Player)
	DataService.DataLoaded[Player.Name] = Signal.new();
	
	local PlayerDataProfile = DataService:LoadProfileAsync(
		DataService.Profiles.PlayerData, Player
	);
	
	if (PlayerDataProfile ~= nil) then
		PlayerDataProfile:ListenToRelease(function() 
			DataService.cached_Profiles[Player] = nil;
			DataService.DataLoaded[Player.Name]:Destroy();
			Player:Kick'Your profile has been reloaded from somewhere else, please rejoin.';
		end);
	else
		DataService.DataLoaded[Player.Name]:Destroy();
		Player:Kick'Unable to load saved data, please rejoin the game.';
	end;
	
	if (Player:IsDescendantOf(game.Players)) then
		DataService.cached_Profiles[Player] = PlayerDataProfile;
		PlayerDataLoaded(Player);
		
		DataService.DataLoaded[Player.Name]:Fire();
	else
		DataService.DataLoaded[Player.Name]:Destroy();
		
		PlayerDataProfile:Release();
	end;
end;

local function PlayerRemoving(Player)
	if (DataService.DataLoaded[Player.Name] ~= nil) then
		DataService.DataLoaded[Player.Name]:Destroy();
	end;
	
	local PlayerDataProfile = DataService.cached_Profiles[Player];
	if (PlayerDataProfile ~= nil) then
		PlayerDataProfile:Release();
	end;
end;

-- Gets a mock ProfileStore
function DataService:GetMockProfileStore(Name, DefaultData)
	return self.DataServiceModule.GetProfileStore(Name, DefaultData).Mock;
end;

-- Gets a ProfileStore
function DataService:GetProfileStore(Name, DefaultData)
	local Profile = self.DataServiceModule.GetProfileStore(Name, DefaultData);
	return Profile;
end;

-- Views a player's profile. Use this if you are not modifying the profile
function DataService:ViewProfileAsync(Profile, Player: Player)
	return Profile:ViewProfileAsync("PLR."..Player.UserId);
end;

-- Loads a player's profile. Use this if yo uare modifying the profile.
function DataService:LoadProfileAsync(Profile, Player)
	return Profile:LoadProfileAsync("PLR."..Player.UserId, "ForceLoad");
end;

-- Wipes a player's profile, resetting it to default.
function DataService:WipeProfileAsync(Profile, Player)
	return Profile:WipeProfileAsync("PLR."..Player.UserId);
end;

-- Gets the MetaData of a profile.
function DataService:FetchProfileMetaData(Profile)
	return Profile.MetaData;
end;

-- Sets a MetaTag of a profile.
function DataService:SetMetaTagOfProfile(Profile, TagName: string, Value)
	Profile:SetMetaTag(TagName, Value);
end;

-- Gets all profiles that are currently loaded.
function DataService:GetCachedProfiles()
	return self.cached_Profiles;
end;

-- Gets a profile currently loaded based on player.
function DataService:GetProfile(Player)
	return self:GetCachedProfiles()[Player];
end;

-- Views an offline profile. Don't use this, I only have it here incase someone wants to patch this up.
function DataService:ViewProfileOfOfflineProfile(Username: string)
	local Done, ID = pcall(game.Players.GetUserIdFromNameAsync, game.Players, Username);
	
	if (not Done or not ID) then
		return 'Error! : '..ID;
	else
		local Done, Profile = pcall(self.LoadProfileAsync, self.Profiles.PlayerData, {UserId = ID});
		
		if (not Done) then
			return 'Error loading profile! : '..Profile..' '..ID;
		end;
		
		if (not Profile) then
			return 'This player has no profile.';
		end;
		
		return Profile;
	end;
end;

-- Gives the client their profile's data.
function DataService.Client:GetData(Player: Player)
    local Profile = self:GetProfile(Player);

    if (Profile) then
        return Profile.Data;
    end;
end;

--[[
	Sets the client data to whatever is passed here.

	**Do not to use this.** 

	If there is any data you want to update from the client, make it its own method.
	For example, if you had options, you can pass the options to the client and then
	when you want to save them, pass them from the client to here and update
	the data accordingly.
]]
-- function DataService.Client:UpdateData(Player: Player, Data)
-- 	local Profile = self:GetProfile(Player);

--     if (Profile) then
--         Profile.Data = Data;
--     end;
-- end;

function DataService:KnitStart()
	for _, Player in ipairs(game.Players:GetPlayers()) do
		task.defer(function()
			PlayerAdded(Player);
		end);
	end
	
	game.Players.PlayerAdded:Connect(PlayerAdded);
	game.Players.PlayerRemoving:Connect(PlayerRemoving);
end;

function DataService:KnitInit()
	self.Profiles = 
		{
			PlayerData = DataService:GetProfileStore("PlayerData", 
				{
                   -- TODO-!-PUT-YOUR-DATA-HERE-!
                }
			);
		};

	ProfileService.IssueSignal:Connect(OnIssueSignalRecieved);
	ProfileService.CriticalStateSignal:Connect();
end;

return DataService;