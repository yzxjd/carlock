--- 模块功能：MQTT客户端数据接收处理
-- @author openLuat
-- @module mqtt.mqttInMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)
require "pins"
require "lockTask"


--使用某些GPIO时，必须在脚本中写代码打开GPIO所属的电压域3v，配置电压输出输入等级，这些GPIO才能正常工作
pmd.ldoset(6,pmd.LDO_VMMC)
lockSetGpioFnc = pins.setup(pio.P0_3,0)

mqttRecMsgAckFlag = 0
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
            lockTask.electoryPowerMeasure()--电压检测
            lockInit.LockStatus = tonumber(tjsondata["CL"])
            lockInit.REMOTECMD = 1
            lockSetGpioFnc(lockInit.LockStatus)
            sys.wait(50)
            mqttOutMsg.myPubAck("lebo/parklot/lockstatus","{\"VER\":\"0\",\"CMD\":\"18\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"CL\":\""..tjsondata["CL"].."\"}",0)    
            log.info("开关锁","led lever:", lockInit.LockStatus, lockInit.AngleValve) 
        end

        ---------------------设备设置相关---------------------
        if tonumber(cmd) == 87 then log.info("遥控器设置") end
        if tonumber(cmd) == 90 then log.info("蜂鸣器设置") end

        if tonumber(cmd) == 27 then log.info("停车时长设置") 
            local ret1 = nvm.sett("lockParas","AutoLockTime",tonumber(tjsondata["TMN"])) --set TMN 有车到无车自动上锁时长
            local ret2 = nvm.sett("lockParas","OpenLockTime",tonumber(tjsondata["TMC"])) --set TMC 开锁一直无车自动上锁时长
            if ret1 and ret2 then
                lockInit.AutoLockTime = tonumber(tjsondata["TMN"])
                lockInit.OpenLockTime = tonumber(tjsondata["TMC"])               
                log.info("set TMN and TMC SUCCESS："..lockInit.AutoLockTime..tjsondata["TMN"]..lockInit.OpenLockTime..tjsondata["TMC"])
                sys.wait(50)
                mqttOutMsg.myPubAck("lebo/parklot/setack",
                                "{\"VER\":\"0\",\"CMD\":\"35\",\"MD\":\"8\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"TMN\":\""..tjsondata["TMN"].."\",\"TMC\":\""..tjsondata["TMC"].."\"}",0) 
            end   
        end

        if tonumber(cmd) == 92 then --log.info("自动上锁设置") 
            local ret = nvm.sett("lockParas","AutomaticLockingTime",tonumber(tjsondata["TM"]))
            if ret then 
                lockInit.AutomaticLockingTime = tonumber(tjsondata["TM"])
                sys.wait(50)
                mqttOutMsg.myPubAck("lebo/parklot/setack",
                                "{\"VER\":\"0\",\"CMD\":\"93\",\"CD\":\""..lockInit.LockDeviceID..
                                "\",\"TM\":\""..tjsondata["TM"].."\"}",0) 
            end
        end

        if tonumber(cmd) == 94 then log.info("断电遇阻设置") end

        if tonumber(cmd) == 89 then --log.info("状态查询") 
            sys.wait(100)
            mqttOutMsg.pubLockHeartBeat()    
        end
    end
end
