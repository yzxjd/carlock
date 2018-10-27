--- 模块功能：MQTT客户端处理框架
-- @author openLuat
-- @module mqtt.mqttTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

require"misc"
require"mqtt"
require"mqttOutMsg"
require"mqttInMsg"

local ready = false

--- MQTT连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage mqttTask.isReady()
function isReady()
    return ready
end

--启动MQTT客户端任务
sys.taskInit(
    function()
        local retryConnectCnt = 0
        while true do
            if not socket.isReady() then
                retryConnectCnt = 0
                --等待网络环境准备就绪，超时时间是5分钟
                sys.waitUntil("IP_READY_IND",300000)
            end

            if socket.isReady() then
                local imei = misc.getImei()
                --创建一个MQTT客户端
                local mqttClient = mqtt.client(imei,180,nil,nil,nil,--,"lebo","MQTT-lebo123456")--,nil,
                -- local mqttClient = mqtt.client(imei,30,"xjdGZS","xjd123456",nil,--,"lebo","MQTT-lebo123456")--,nil,
                        --will 遗言
                        {qos=2, retain=1, topic="lebo/parklot/getstatus",
                        payload="{\"VER\":\"0\",\"CMD\":\"12\""
                        ..",\"MD\":\""..tostring(lockInit.GatewayID)..
                        "\",\"CD\":\""..lockInit.LockDeviceID..
                        "\",\"CS\":\""..tostring(81)..--离线默认为有车
                        "\",\"LS\":\""..tostring(0)..
                        "\",\"BS\":\""..tostring(0)..
                        "\",\"NG\":\""..tostring(0).."\"}"})
                --阻塞执行MQTT CONNECT动作，直至成功
                --如果使用ssl连接，打开mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})，根据自己的需求配置
                --mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})
                -- if mqttClient:connect("47.106.101.59",1994,"tcp") then
                -- if mqttClient:connect("58.20.51.165",1883,"tcp") then
                if mqttClient:connect("112.74.132.1",1884,"tcp") then
                    retryConnectCnt = 0
                    ready = true
                    --订阅主题
                    if mqttClient:subscribe({["lebo/parklot/set/"..tostring(lockInit.GatewayID)]=0, ["lebo/parklot/lock/"..tostring(lockInit.GatewayID)]=1}) then
                        lockInit.mqttConnectStatusFlag = 1
                        mqttOutMsg.init()
                        --循环处理接收和发送的数据
                        while true do
                            if not mqttInMsg.proc(mqttClient) then log.error("mqttTask.mqttInMsg.proc error") break end
                            if not mqttOutMsg.proc(mqttClient) then log.error("mqttTask.mqttOutMsg proc error") break end
                        end
                        lockInit.mqttConnectStatusFlag = 0
                        mqttOutMsg.unInit()
                    end
                    ready = false
                else
                    lockInit.mqttConnectStatusFlag = 0
                    retryConnectCnt = retryConnectCnt+1
                end
                --断开MQTT连接
                mqttClient:disconnect()
                if retryConnectCnt>=5 then link.shut() retryConnectCnt=0 end
                sys.wait(5000)
            else
                --进入飞行模式，20秒之后，退出飞行模式
                net.switchFly(true)
                log.info("进入飞行模式")
                sys.wait(20000)
                log.info("退出飞行模式")
                net.switchFly(false)
            end
        end
    end
)
