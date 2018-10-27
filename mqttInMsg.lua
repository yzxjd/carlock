--- 模块功能：MQTT客户端数据接收处理
-- @author openLuat
-- @module mqtt.mqttInMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)
require "pins"
require "lockTask"


--mqttRecMsgAckFlag = 0
--- MQTT客户端数据接收处理
-- @param mqttClient，MQTT客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage mqttInMsg.proc(mqttClient)
function proc(mqttClient)
    local result,data

    while true do
        result,data = mqttClient:receive(2000)
        --接收到数据
        if result then
            log.info("mqttInMsg.proc",data.topic,data.payload)--string.toHex(data.payload))
            lockMqttMsgProcess(data.payload)

            --如果mqttOutMsg中有等待发送的数据，则立即退出本循环
            if mqttOutMsg.waitForSend() then return true end
        else
            break
        end
    end
    return result or data=="timeout"
end

function lockMqttMsgProcess(mqttMsgPayload)
    local tjsondata,decodeResult,errinfo = json.decode(mqttMsgPayload)
    --TODO：根据需求自行处理data.payload
    if decodeResult then
        local cmd = tjsondata["CMD"]

        ---------------------开关锁相关---------------------
        if tonumber(cmd) == 17 then
            lockInit.LockStatus = tonumber(tjsondata["CL"])
            lockInit.REMOTECMD = 1
            sys.wait(50)
            mqttOutMsg.myPubAck("lebo/parklot/lockstatus","{\"VER\":\"0\",\"CMD\":\"18\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"CL\":\""..tjsondata["CL"].."\"}",0)    
            log.info("开关锁","led lever:", lockInit.LockStatus, lockInit.AngleValve) 
        end

        ---------------------设备设置相关---------------------
        if tonumber(cmd) == 27 then log.info("停车时长设置") 
            local ret1 = nvm.sett("lockParas","AutoLockTime",tonumber(tjsondata["TMN"])) --set TMN 有车到无车自动上锁时长
            local ret2 = nvm.sett("lockParas","OpenLockTime",tonumber(tjsondata["TMC"])) --set TMC 开锁一直无车自动上锁时长
            if ret1 and ret2 then
                lockInit.AutoLockTime = tonumber(tjsondata["TMN"])
                lockInit.OpenLockTime = tonumber(tjsondata["TMC"])               
                log.info("set TMN and TMC SUCCESS："..lockInit.AutoLockTime..tjsondata["TMN"]..lockInit.OpenLockTime..tjsondata["TMC"])
                sys.wait(50)
                mqttOutMsg.myPubAck("lebo/parklot/setack",
                                "{\"VER\":\"0\",\"CMD\":\"35\",\"MD\":\""
                                ..tostring(lockInit.GatewayID)..
                                "\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"TMN\":\""..tjsondata["TMN"]..
                                "\",\"TMC\":\""..tjsondata["TMC"].."\"}",0) 
            end   
        end

        if tonumber(cmd) == 87 then log.info("遥控器设置") end
        if tonumber(cmd) == 90 then --log.info("蜂鸣器设置")
            local ret1 = nvm.sett("lockParas","AlarmLedENABLE",tonumber(tjsondata["EB"])) --set TMN 有车到无车自动上锁时长
            local ret2 = nvm.sett("lockParas","AlarmTime",tonumber(tjsondata["TM"]))
            if ret1 and ret2 then
                lockInit.AlarmLedENABLE = tonumber(tjsondata["EB"])
                lockInit.AlarmTime = tonumber(tjsondata["TM"])               
                log.info("set EB and TM SUCCESS：")
                sys.wait(50)
                mqttOutMsg.myPubAck("lebo/parklot/setack",
                                "{\"VER\":\"0\",\"CMD\":\"91\",\"MD\":\""
                                ..tostring(lockInit.GatewayID)..
                                "\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"EB\":\""..tjsondata["EB"]..
                                "\",\"TM\":\""..tjsondata["TM"].."\"}",0) 
            end
        end

        if tonumber(cmd) == 91 then log.info("故障时间设置") 
            local ret1 = nvm.sett("lockParas","LockProcDifficultTime",tonumber(tjsondata["TU"])) --上锁遇阻多久自动开锁时间
            local ret2 = nvm.sett("lockParas","LockStateDifficultTime",tonumber(tjsondata["TD"]))--上锁状态强压多久自动开锁时间
            if ret1 and ret2 then
                lockInit.LockProcDifficultTime = tonumber(tjsondata["TU"])
                lockInit.LockStateDifficultTime = tonumber(tjsondata["TD"])               
                log.info("set TU and TD SUCCESS：")
                sys.wait(50)
                mqttOutMsg.myPubAck("lebo/parklot/setack",
                                "{\"VER\":\"0\",\"CMD\":\"92\",\"MD\":\""
                                ..tostring(lockInit.GatewayID)..
                                "\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"TU\":\""..tjsondata["TU"]..
                                "\",\"TD\":\""..tjsondata["TD"].."\"}",0) 
            end
        end

        if tonumber(cmd) == 92 then --log.info("自动上锁设置") 
            local ret = nvm.sett("lockParas","AutomaticLockingTime",tonumber(tjsondata["TM"]))
            if ret then 
                lockInit.AutomaticLockingTime = tonumber(tjsondata["TM"])
                sys.wait(50)
                mqttOutMsg.myPubAck("lebo/parklot/setack",
                                "{\"VER\":\"0\",\"CMD\":\"93\",\"CD\":\""
                                ..lockInit.LockDeviceID..
                                "\",\"TM\":\""..tjsondata["TM"].."\"}",0) 
            end
        end  

        if tonumber(cmd) == 94 then log.info("遇阻参数设置") 
            local ret1 = nvm.sett("lockParas","OverCurrProEnable",tonumber(tjsondata["EB"]))
            local ret2 = nvm.sett("lockParas","OverCurrProPar",tonumber(tjsondata["CC"]))
            local ret3 = nvm.sett("lockParas","OverCurrProTime",tonumber(tjsondata["TM"]))
            if ret1 and ret2 and ret3 then
                lockInit.OverCurrProEnable = tonumber(tjsondata["EB"])
                lockInit.OverCurrProPar = tonumber(tjsondata["CC"])
                lockInit.OverCurrProTime = tonumber(tjsondata["TM"])               
                log.info("set EB CC TM SUCCESS：")
                sys.wait(50)
                mqttOutMsg.myPubAck("lebo/parklot/setack",
                                "{\"VER\":\"0\",\"CMD\":\"95\",\"MD\":\""
                                ..tostring(lockInit.GatewayID)..
                                "\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"EB\":\""..tjsondata["EB"]..
                                "\",\"CC\":\""..tjsondata["CC"]..
                                "\",\"TM\":\""..tjsondata["TM"].."\"}",0) 
            end
        end

        if tonumber(cmd) == 89 then --log.info("状态查询") 
            sys.wait(50)
            mqttOutMsg.pubLockHeartBeat()    
        end
    end
end
