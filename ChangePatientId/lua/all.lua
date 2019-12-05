
ENV = loadfile('/etc/lua/_env.lua')()
SHA1 = loadfile('/etc/lua/sha1.lua')()
READCONFIG = loadfile('/etc/lua/readConfig.lua')()

ID_UNIDADE = ENV.ID_UNIDADE

ENFORCE_UNIQUE_PATIENT = false

function OnStoredInstance(instanceId, tags, metadata, origin)

  local config = READCONFIG.readFile();

  local info = {}
  info['event'] = 'OnStoredInstance'
  info['instanceId'] = instanceId
  info['origin'] = origin
  info['metadata'] = metadata
  info['tags'] = tags


  if(config['ENFORCE_UNIQUE_PATIENT'] ~= nil) then
    ENFORCE_UNIQUE_PATIENT = config['ENFORCE_UNIQUE_PATIENT']
  end

  if (ENFORCE_UNIQUE_PATIENT == true and origin['RequestOrigin'] ~= 'Lua') then

    _modifyPatientIdTag(instanceId, tags, metadata, origin, info)

  end

end

function IncomingHttpRequestFilter(method, uri, ip, username, httpHeaders)
  local config = READCONFIG.readFile();
  if (method == 'DELETE') then
    if (username == config['ADMIN_USER_NAME']) then
      return true
    end
    return false
  end
  return true
 end

-- #################################################################
function _modifyPatientIdTag(instanceId, tags, metadata, origin, info)
    -- The tags to be replaced
    local replace = {}
    replace['0010,0020'] = ID_UNIDADE .. "_" .. tags['PatientID']
    replace['0020,000d'] = tags['StudyInstanceUID']
    replace['0020,000e'] = tags['SeriesInstanceUID']
    replace['0008,0018'] = tags['SOPInstanceUID']

    local hashAsHex = SHA1.hex(replace['0010,0020'] .. "|" .. replace['0020,000d'] .. "|".. replace['0020,000e'] .. "|" .. replace['0008,0018'])

    local isAlreadyLoaded = true
    local status, ref = pcall(RestApiGet, "/instances/" .. hashAsHex );
    local refJson = nil
    if(status == true ) then
      refJson = ParseJson(ref)
      isAlreadyLoaded = (type(refJson) ~= 'nil')
    end

    print("isAlreadyLoaded " .. string.format("%s", isAlreadyLoaded) )

   -- Ignore the instances that result from the present Lua script to
   -- avoid infinite loops

   if (origin['RequestOrigin'] ~= 'Lua' and  isAlreadyLoaded == true ) then
    -- esse caso acontece qnd a instancia já foi carregada, porem o SOPInstanceMap ainda tem o true setando
    -- SOPInstanceMap só é resetado qndo um novo estudo é estabilizado
      RestApiDelete('/instances/' .. instanceId)
   end

  if (origin['RequestOrigin'] ~= 'Lua' and isAlreadyLoaded == false ) then

    -- Modify the instance
    local command = {}
    command['Replace'] = replace
    command['Force'] = true

    print("Modifying instanceId " .. instanceId)

    local modifiedFile = RestApiPost('/instances/' .. instanceId .. '/modify', DumpJson(command, true))

    -- Upload the modified instance to the Orthanc database
    local retPost = RestApiPost('/instances/', modifiedFile)

    -- Delete the original instance
    RestApiDelete('/instances/' .. instanceId)

  end

end





