--- 模块功能：车位锁控制及状态采集任务
-- @author 熊健东
-- @module lock.lockTask
-- @license MIT
-- @copyright lebo
-- @release 2018.10.11

module(...,package.seeall)

require"lockInit"
require"ultrasonic"
require"pins"

--使用某些GPIO时，必须在脚本中写代码打开GPIO所属的电压域3v，配置电压输出输入等级，这些GPIO才能正常工作
pmd.ldoset(6,pmd.LDO_VMMC)

--电机驱动io配置
lockMotorGpioFncIN  = pins.setup(pio.P0_6,0,pio.PULLUP) --motor+
lockMotorGpioFncOUT = pins.setup(pio.P0_7,0,pio.PULLUP) --motor-

--红外对管驱动引脚io配置
infraredSendGpioFnc = pins.setup(pio.P0_29,1,pio.PULLUP)--红外发射引脚
infraredReceiveGpioFncA = pins.setup(pio.P0_10,nil, pio.PULLUP)--IN_DECT 没接收到为高电平 接收到为低电平
infraredReceiveGpioFncB = pins.setup(pio.P0_12,nil, pio.PULLUP)--OUT_DECT没接收到为高电平 接收到为低电平
infraredSendGpioFnc(1)   --关闭红外对管发射端

--超声波电源控制io配置
ultrasonicPowerCtrl = pins.setup(pio.P0_8,1,pio.PULLUP)
ultrasonicPowerCtrl(1)  --打开超声波电源

--蜂鸣器电源控制io配置
alarmGpioFncOUT     = pins.setup(pio.P0_11,0)--alarm


--锁摆臂角度测量
--用于控制摆臂上摆下摆参照
function angleMeasure()
    if lockInit.mqttPubFlag == 0 then
        lockInit.lockActiveFlag = 1
        infraredSendGpioFnc(1)   --打开红外对管发射端
        -- log.info( "get in angleMeasure" )
        rtos.sleep(50)
        if ( infraredReceiveGpioFncA() == 1 and  infraredReceiveGpioFncB() == 1) then   
            lockInit.AngleValve = 0  --表示在0度
        elseif ( infraredReceiveGpioFncA() == 1 and  infraredReceiveGpioFncB() == 0 ) then
            lockInit.AngleValve = 45 --表示在0~90度之间
        elseif ( infraredReceiveGpioFncA() == 0 and  infraredReceiveGpioFncB() == 0 ) then
            lockInit.AngleValve = 90 --表示在90度
        elseif ( infraredReceiveGpioFncA() == 0 and  infraredReceiveGpioFncB() == 1 ) then
            lockInit.AngleValve = 135 --表示在90~180度之间  
        end        
    end
    infraredSendGpioFnc(0)   --关闭红外对管发射端
    lockInit.lockActiveFlag = 0
    -- log.info("AngleValve:", "----------------------------------", lockInit.AngleValve)  
    return lockInit.AngleValve
end

--电机开锁转动
function motorDownRunning()
    lockMotorGpioFncIN(1)
    lockInit.lockMotoINStatus = 1
    lockMotorGpioFncOUT(0)
    lockInit.lockMotoOUTStatus = 0
end

--电机上锁转动
function motorUpRunning()
    lockMotorGpioFncIN(0)
    lockInit.lockMotoINStatus = 0
    lockMotorGpioFncOUT(1)
    lockInit.lockMotoOUTStatus = 1
end

--电机停止转动
function motorStopRunning()
    lockMotorGpioFncIN(0)
    lockInit.lockMotoINStatus = 0
    lockMotorGpioFncOUT(0)
    lockInit.lockMotoOUTStatus = 0
end

--蜂鸣器打开    
function alarmOpen()
    alarmGpioFncOUT(1)
end

--蜂鸣器关闭
function alarmClose()
    alarmGpioFncOUT(0)
end

function alarmLoop()

end

--电压检测功能函数
local ADC_ID = 0
function electoryPowerMeasure()
     -- 打开adc
    adc.open(ADC_ID)
    -- 读取adc
    -- adcval为number类型，表示adc的原始值，无效值为0xFFFF
    -- voltval为number类型，表示转换后的电压值，单位为毫伏，无效值为0xFFFF；adc.read接口返回的voltval放大了3倍，所以需要除以3还原成原始电压
    local adcval,voltval = adc.read(ADC_ID)
    local voltvalMv = (voltval-(voltval%3))/3    --单位mv
    --发送出的电压数据转换,string.format()格式化转换，将10进制转成16进制字符串
    local voltvalSend = math.ceil(voltvalMv*11*(0.001/0.01176))
    lockInit.ElectricityADC = string.format("%x",voltvalSend)
    -- log.info("testAdc.read",adcval,(voltval-(voltval%3))/3,voltval)
    log.info("ElectricityADC",voltvalMv,lockInit.ElectricityADC)   
    
    --如果adcval有效
    if adcval and adcval~=0xFFFF then
    end
    --如果voltval有效	
    if voltval and voltval~=0xFFFF then
        --adc.read接口返回的voltval放大了3倍，所以此处除以3
        voltval = (voltval-(voltval%3))/3
    end
    if tonumber((rtos.get_version()):match("Luat_V(%d+)_"))>=27 then
        adc.close(ADC_ID)
    end
end

--车位有无停车状态检测
--调用串口超声波测距模块测量距离
function parkingStatusMeasure()
        ultrasonic.write(0x55)
        log.info("---distance measure require---")
end

function lockTask()
    ParkingReservationMainLoop()
end

function SysTick_GetLapse(Preticks)
    CurTick = rtos.tick()
    return (CurTick > Preticks) and (CurTick-Preticks) or (0xffffffff-Preticks+CurTick)
end

function ParkingReservationMainLoop()
    if lockInit.REMOTECMD == 1 then
        if lockInit.LockStatus == 0 then
            lockInit.PROCN = 20 --远程开锁指令   
        elseif lockInit.LockStatus == 1 then
            lockInit.PROCN = 30 --远程上锁指令
        end  
    else 
        if lockInit.LockStatus == 0 then
            -- lockInit.PROCN = 0 --保持开锁
        elseif lockInit.LockStatus == 1 then
            lockInit.PROCN = 1 --保持上锁
        end
    end
    
    if lockInit.PROCN == 10 then    --任务初始化
        angleMeasure()
        lockInit.AngleValueBffer = lockInit.AngleValve
        lockInit.PROCN = 0
    elseif lockInit.PROCN == 0 then --0度开锁
        if lockInit.AngleValve ~= 0 then
            motorDownRunning()
        else
            motorStopRunning()
            lockInit.PreLockStatus = 0
            lockInit.LockStatus = 0
        end
    elseif lockInit.PROCN == 1 then --90度上锁
        if lockInit.ParkingStatus == 0 then --无车
            if lockInit.AngleValve == 0 then
                if (lockInit.mqttPubFlag == 1) or (lockInit.mqttHeartBeatSendFlag == 1) then --如果在发布数据,则当检测到角度在0度时停止电机转动，跳过因mqtt发送数据包时对角度检测的空窗区
                    motorStopRunning()
                else
                    motorUpRunning()
                end
            elseif lockInit.AngleValve == 45 then
                motorUpRunning()
            elseif lockInit.AngleValve == 135 then
                motorDownRunning()
            else --上锁完成
                motorStopRunning()
                lockInit.PreLockStatus = 1
                lockInit.LockStatus = 1
                if lockInit.autoLockFlag == 1 then
                    sys.wait(3300) --防止电机转动刚停止就发数据导致摆臂抖动
                    lockInit.autoLockFlag = 0
                    mqttOutMsg.myPubAck("lebo/parklot/getstatus","{\"VER\":\"0\",\"CMD\":\"12\",\"MD\":\"8\",\"CD\":\""..lockInit.LockDeviceID..
                                            "\",\"CS\":\""..tostring(lockInit.ParkingStatus)..
                                            "\",\"LS\":\""..tostring(lockInit.LockStatus)..
                                            "\",\"BS\":\""..tostring(lockInit.ElectricityADC)..
                                            "\",\"NG\":\""..tostring(lockInit.AbnormalSign).."\"}",0) --自动上锁完成后则上传一次状态
                end

            end
        else
            motorStopRunning()
        end
    elseif lockInit.PROCN == 20 then --收到开锁命令
        if lockInit.REMOTECMD == 1 then lockInit.REMOTECMD = 0 end --清0远程开锁命令标志
        if lockInit.AngleValve ~= 0 then
            motorDownRunning()
        else
            motorStopRunning()
            lockInit.PreLockStatus = 0
            lockInit.LockStatus = 0
        end

        if lockInit.AUTO_CLOSE_LOCK_MODE == 1 then  --自动上锁逻辑
            if lockInit.OpenLockTime ~= 0 then
                if (lockInit.ParkingStatus == 0) and (lockInit.LockStatus == 0) and (lockInit.automaticLockEnable ~= 1) then --无车处理
                    if lockInit.preOpenLockTimeTicks == 0 then
                        lockInit.preOpenLockTimeTicks = rtos.tick() 
                    end   
                    if (lockInit.preOpenLockTimeTicks~=0) and (SysTick_GetLapse(lockInit.preOpenLockTimeTicks) > (lockInit.OpenLockTime*16384)) then --从开锁为止一直无车超过该设置时间自动上锁
                        lockInit.preOpenLockTimeTicks = 0
                        log.info("outo lock from TMC")
                        lockInit.PROCN = 1 --自动上锁
                        lockInit.autoLockFlag = 1
                    end
                elseif lockInit.ParkingStatus == 1 then --在开锁后有停车了
                    lockInit.preOpenLockTimeTicks = 0
                end
            else
                lockInit.PROCN = 0  --开锁
            end
        end

    elseif lockInit.PROCN == 30 then --收到上锁命令
        if lockInit.REMOTECMD == 1 then lockInit.REMOTECMD = 0 end --清0远程上锁命令标志
        lockInit.PreLockStatus = 1
    else 
        lockInit.LockStatus = 1
        lockInit.PreLockStatus = 1
        lockInit.PROCN = 1 --上锁
    end 

    if lockInit.AUTO_CLOSE_LOCK_MODE == 1 then  
        if lockInit.AutoLockTime ~= 0 then
            if (lockInit.ParkingStatus == 0) and (lockInit.AngleValve == 0) then --无车处理
                if (lockInit.automaticLockEnable == 1) and (lockInit.preParkingStatus ~= lockInit.ParkingStatus) and (lockInit.automaticLockCtrlFlag == 0) then --从有车到无车变化且之前停车超过自动上锁时长
                    log.info("outo lock 6")
                    lockInit.automaticLockCtrlFlag = 1
                    lockInit.preParkingStatus = 0
                    if lockInit.preAutomaticLockTicks == 0 then
                        lockInit.preAutomaticLockTicks = rtos.tick()
                    end
                elseif (lockInit.automaticLockEnable == 0) and (lockInit.preParkingStatus ~= lockInit.ParkingStatus) and (lockInit.automaticLockCtrlFlag == 0) then--从有车到无车变化，但停车没超过有车自动上锁时长
                    log.info("outo lock 1")
                    lockInit.preParkingStatus = 0
                    lockInit.preAutomaticLockTicks = 0 --从新计时
                    lockInit.preHaveCarTicks = 0
                    lockInit.automaticLockCtrlFlag1 = 0
                end

                if (lockInit.automaticLockCtrlFlag == 1) and (lockInit.automaticLockEnable == 1) and (lockInit.preAutomaticLockTicks~=0) then
                    if (lockInit.preAutomaticLockTicks ~= 0) and (SysTick_GetLapse(lockInit.preAutomaticLockTicks) > (lockInit.AutoLockTime*16384)) then
                        lockInit.preAutomaticLockTicks = 0
                        lockInit.automaticLockEnable = 0
                        lockInit.automaticLockCtrlFlag = 0
                        log.info("outo lock from TMN")
                        --自动上锁
                        lockInit.PROCN = 1
                        lockInit.autoLockFlag = 1
                    end
                end
            elseif lockInit.ParkingStatus == 1 then --有车处理
                if (lockInit.preParkingStatus ~= lockInit.ParkingStatus) and (lockInit.automaticLockCtrlFlag1 == 0) then
                    log.info("outo lock 3")
                    lockInit.automaticLockCtrlFlag1 = 1
                    lockInit.preParkingStatus = 1
                    if lockInit.preHaveCarTicks == 0 then
                        lockInit.preHaveCarTicks = rtos.tick()
                    end
                end

                --记录停车时长用于判断车离后是否自动上锁
                if lockInit.automaticLockCtrlFlag1 == 1 then
                    if (lockInit.preHaveCarTicks ~= 0) and SysTick_GetLapse(lockInit.preHaveCarTicks) > (lockInit.AutomaticLockingTime*16384) then
                        log.info("have car time over OpenLockTime")
                        lockInit.preHaveCarTicks = 0
                        lockInit.automaticLockEnable = 1
                        lockInit.automaticLockCtrlFlag1 = 0
                    end
                end
                
            end
        else
            lockInit.PROCN = 0
        end
    end

    angleMeasure()
    if lockInit.AngleValve == 0 or lockInit.AngleValve == 90 then
        if pio.pin.getval(pio.P0_6) == 0 and pio.pin.getval(pio.P0_7) then
            --休眠操作
        else
            --休眠操作
        end
    else

    end

    --故障分析处理   
end


sys.taskInit(
    function()
        local distanceMeasureTicks = 0
        local predistanceMeasureTicks = 0
        local distanceMeasureFlag = 0
        while true do
            lockTask()

            --开锁状态下周期检测有无车状态逻辑
            if lockInit.lockMotoINStatus == 0 and lockInit.lockMotoOUTStatus == 0 then --电机没动作
                if lockInit.AngleValve == 0 then             --处于0度开锁状态
                    if predistanceMeasureTicks == 0 then
                        predistanceMeasureTicks = rtos.tick()
                    end
                    distanceMeasureTicks = rtos.tick()
                    local tempDifference  = distanceMeasureTicks - predistanceMeasureTicks
                    if tempDifference > 114688 and  tempDifference < 163840 then --7~10s之间
                        ultrasonicPowerCtrl(1)              --打开超声波电源
                    end
                    if tempDifference > 163840 then --10s
                        if distanceMeasureFlag == 0 then    --每个周期只发一次测量请求
                            distanceMeasureFlag = 1
                            parkingStatusMeasure()
                        end
                    end
                    if tempDifference > 168755 then --10.3s                    
                        ultrasonicPowerCtrl(0)              --关闭超声波电源
                        predistanceMeasureTicks = 0         --周期从新开始
                        distanceMeasureTicks = 0   
                        distanceMeasureFlag =0                    
                    end
                elseif lockInit.AngleValve == 90 then       --处于90度上锁状态
                    ultrasonicPowerCtrl(0)                  --关闭超声波电源
                    predistanceMeasureTicks = 0             --周期从新开始
                    distanceMeasureTicks = 0
                    distanceMeasureFlag =0
                end
            else
                ultrasonicPowerCtrl(0)  --关闭超声波电源
                predistanceMeasureTicks = 0 --周期从新开始
                distanceMeasureTicks = 0
                distanceMeasureFlag =0
            end

            sys.wait(20)
        end
    end
)
