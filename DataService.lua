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
	cached_Profiles = {};
	DataServiceModule = ProfileService;
	Data_Version = 'REDUX';
	DataLoaded = {};
};

local function OnIssueSignalRecieved(ErrorMessage, ProfileStoreName, ProfileKey)
	warn('[DataService] ProfileService issue:', ErrorMessage);
end;

local function OnCriticalStateSignalRecieved(IsCritical)
	warn('[DataService] ProfileService issue: DataStore issues are now',IsCritical and 'critical.' or 'okay.')
end;

-- TODO Make this an event.
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
	
	spawn(function()
		repeat
			
			task.wait();
			
			local PlayerDataProfile = DataService.cached_Profiles[Player];
			
			if (PlayerDataProfile ~= nil) then
				-- Update anything like leaderstats here
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
			
			Player:Kick'Your profile has been reloaded from somewhere else, please rejoin. (nice try at duping :3)';
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
		if (#game.Players:GetChildren() > 0) then

		end;
		
	end;
end;

function DataService:GetMockProfileStore(Name, DefaultData)
	return self.DataServiceModule.GetProfileStore(Name, DefaultData).Mock;
end;

function DataService:GetProfileStore(Name, DefaultData)
	local Profile = self.DataServiceModule.GetProfileStore(Name, DefaultData);
	return Profile;
end;

function DataService:ViewProfileAsync(Profile, Player: Player)
	return Profile:ViewProfileAsync("PLR."..Player.UserId);
end;

function DataService:LoadProfileAsync(Profile, Player)
	return Profile:LoadProfileAsync("PLR."..Player.UserId, "ForceLoad");
end;

function DataService:WipeProfileAsync(Profile, Player)
	return Profile:WipeProfileAsync("PLR."..Player.UserId);
end;

function DataService:FetchProfileMetaData(Profile)
	return Profile.MetaData;
end;

function DataService:SetMetaTagOfProfile(Profile, TagName: string, Value)
	Profile:SetMetaTag(TagName, Value);
end;

function DataService:GetCachedProfiles()
	return self.cached_Profiles;
end;

function DataService:GetProfile(Player)
	return self:GetCachedProfiles()[Player];
end;

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

-- TODO-Remove-this-if-you-do-not-want-the-client-to-fetch-data 
function DataService.Client:GetData(Player: Player)
    local Profile = self:GetProfile(Player);

    if (Profile) then
        return Profile.Data;
    end;
end;

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