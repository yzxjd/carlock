--- 模块功能：MQTT客户端数据发送处理
-- @author openLuat
-- @module mqtt.mqttOutMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28


module(...,package.seeall)

require "lockInit"

--数据发送的消息队列
local msgQueue = {}


--qos0 只发一次，broker可能收不到
--qos1 至少发送一次，broker可能收到重复包
--qos2 保证消息不丢失不重复，broker肯定会收到且只收到一次消息
local function insertMsg(topic,payload,qos,user)
    lockInit.mqttPubFlag = 1
    table.insert(msgQueue,{t=topic,p=payload,q=qos,user=user})
end

local function pubLockHeartBeatCb(result)
    log.info("mqttOutMsg.pubLockHeartBeatCb",result)
    if result then sys.timerStart(pubLockHeartBeat,60000) end
end

--{"VER":"0","CMD":"12","MD":"7","CD":"6ff1007","CS":"0","LS":"0","BS":"29f","NG":"0"}
function pubLockHeartBeat()
    if lockInit.lockActiveFlag ~= 1 then --如果锁在动作或者采集检测时，禁止发送心跳包
        lockInit.mqttHeartBeatSendFlag = 1 --发送心跳标注位
        local lockStatusPubTopic = "lebo/parklot/getstatus"
        local payload = "{\"VER\":\"0\",\"CMD\":\"12\",\"MD\":\""
                        ..tostring(lockInit.GatewayID)..
                        "\",\"CD\":\""..lockInit.LockDeviceID..
                        "\",\"CS\":\""..tostring(lockInit.ParkingStatus)..
                        "\",\"LS\":\""..tostring(lockInit.LockStatus)..
                        "\",\"BS\":\""..tostring(lockInit.ElectricityADC)..
                        "\",\"NG\":\""..tostring(lockInit.AbnormalSign).."\"}"
        insertMsg(lockStatusPubTopic,payload,0,{cb=pubLockHeartBeatCb})
    else
        log.info("this lock is active,can not send heart beat")
    end
end

local function myPubAckCb(result)
    log.info("mqttOutMsg.myPubAckCb",result)
    if result then 
        log.info("wait cb done")
    else
        log.info("no cb response")
    end
end

function myPubAck(topic,payload,qos)
    log.info("get in myPubAck")
    insertMsg(topic,payload,qos,{cb=myPubAckCb})
end


--- 初始化“MQTT客户端数据发送”
-- @return 无
-- @usage mqttOutMsg.init()
function init()
    -- pubQos0Test()
    pubLockHeartBeat()--状态心跳
end

--- 去初始化“MQTT客户端数据发送”
-- @return 无
-- @usage mqttOutMsg.unInit()
function unInit()
    -- sys.timerStop(pubQos0Test)
    sys.timerStop(pubLockHeartBeat)
    while #msgQueue>0 do
        local outMsg = table.remove(msgQueue,1)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(false,outMsg.user.para) end
    end
end

--- MQTT客户端是否有数据等待发送
-- @return 有数据等待发送返回true，否则返回false
-- @usage mqttOutMsg.waitForSend()
function waitForSend()
    return #msgQueue > 0
end

--- MQTT客户端数据发送处理
-- @param mqttClient，MQTT客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage mqttOutMsg.proc(mqttClient)
function proc(mqttClient)
    local flag = 0
    while #msgQueue>0 do
        lockInit.mqttPubFlag = 1
        local outMsg = table.remove(msgQueue,1)
        local result = mqttClient:publish(outMsg.t,outMsg.p,outMsg.q)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(result,outMsg.user.para) end
        if not result then return end
        flag = 1
    end

    if flag == 1 then --如果刚发送完mqtt数据,则延迟1s后才能进行其他采集操作
        if lockInit.mqttHeartBeatSendFlag == 1 then --如果是心跳包发送完成，间隔3S后才能继续检测角度
            sys.wait(1000)
            lockInit.mqttHeartBeatSendFlag = 0
        end
        sys.wait(1000)
        lockInit.mqttPubFlag = 0
        flag = 0
    else
        lockInit.mqttPubFlag = 0
    end

    return true
end


