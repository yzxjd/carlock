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

--------------------------------------硬件控制io定义及初次初始化-------------------------------------
--使用某些GPIO时，必须在脚本中写代码打开GPIO所属的电压域3v，配置电压输出输入等级，这些GPIO才能正常工作
pmd.ldoset(5,pmd.LDO_VMMC)

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

--led控制io配置
lockLedGpioFnc = pins.setup(pio.P0_3,0)
--------------------------------------------------------------------------------------------

--运行时需要低功耗处理的io初始化
function hardwareIOInit()
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

    --led控制io配置
    lockLedGpioFnc = pins.setup(pio.P0_3,0)
end

--低功耗所需失能io口
function hardwareIODeleteInit()
    infraredSendGpioFnc = pins.setup(pio.P0_29,nil)--红外发射引脚设成输入模式
end

--锁摆臂角度测量
--用于控制摆臂上摆下摆参照
function angleMeasure()
    if lockInit.mqttPubFlag == 0 then
        lockInit.lockActiveFlag = 1
        infraredSendGpioFnc = pins.setup(pio.P0_29,1,pio.PULLUP)--红外发射引脚
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
    infraredSendGpioFnc = pins.setup(pio.P0_29,nil)--红外发射引脚设成输入模式
    lockInit.lockActiveFlag = 0
    -- log.info("AngleValve:", "----------------------------------", lockInit.AngleValve)  
    return lockInit.AngleValve
end

--电机开锁转动
function motorDownRunning()
    if lockInit.OVER_CURR_DETEC_EN == 1 and lockInit.OverCurrProEnable == 1 and lockInit.AngleValve == 45 then
            local tempRatio = lockInit.OverCurrProPar/100
            local VolValueTemp = electoryPowerMeasure()
            if VolValueTemp < (lockInit.OverCurrProValue - lockInit.OverCurrProValue*tempRatio) then
                if SysTick_GetLapse(lockInit.downLockRunTicks) > 800 then --超过过流超过50ms
                    motorStopRunning()
                    for i = 1, lockInit.OverCurrProTime do
                        sys.wait(1000)  --电机停转这么多秒后再运行
                    end    
                end
            else
                lockInit.downLockRunTicks = rtos.tick()
                lockMotorGpioFncIN(1)
                lockMotorGpioFncOUT(0)
            end
    else
        lockMotorGpioFncIN(1)
        lockMotorGpioFncOUT(0)
    end
end

--电机上锁转动
function motorUpRunning()
    if lockInit.OVER_CURR_DETEC_EN == 1 and lockInit.OverCurrProEnable == 1 and lockInit.AngleValve == 45 then
        local tempRatio = lockInit.OverCurrProPar/100
        local VolValueTemp = electoryPowerMeasure()
        if VolValueTemp < (lockInit.OverCurrProValue - lockInit.OverCurrProValue*tempRatio) then
            if SysTick_GetLapse(lockInit.upLockRunTicks) > 16384 then --超过过流超过1000ms
                motorStopRunning()
                for i = 1, lockInit.OverCurrProTime do
                    sys.wait(1000)  --电机停转这么多秒后再运行
                end    
            end
        else
            lockInit.upLockRunTicks = rtos.tick()
            lockMotorGpioFncIN(0)
            lockMotorGpioFncOUT(1)
        end
    else
        lockMotorGpioFncIN(0)
        lockMotorGpioFncOUT(1)
    end
end

--电机停止转动
function motorStopRunning()
    lockMotorGpioFncIN(0)
    lockMotorGpioFncOUT(0)
end

--蜂鸣器打开    
function alarmOpen()
    alarmGpioFncOUT(1)
end

--蜂鸣器关闭
function alarmClose()
    alarmGpioFncOUT(0)
end

--led亮
function ledOn()
    lockLedGpioFnc(1)
end

--led灭
function ledOff()
    lockLedGpioFnc(0)
end


--声光报警提示
function statusLedAndAlarm()
    local tempticks = 0
    if lockInit.AlarmLedENABLE == 1 then --启用了声光报警
        if lockInit.ALARM_LED_FLAG == 1 and (SysTick_GetLapse(lockInit.preAlarmTotalTicks) <= 5*16384) then --最大5s钟
            tempticks = SysTick_GetLapse(lockInit.preAlarmTicks)
            if lockInit.ALARM_PROCN == 0 then
                alarmOpen()
                ledOn()
                if tempticks >= (lockInit.AlarmTime*16) then 
                    lockInit.ALARM_PROCN = 1
                end
            elseif lockInit.ALARM_PROCN == 1 then
                ledOff()
                alarmClose()
                if tempticks >= (lockInit.AlarmTime*2*16) then
                    lockInit.ALARM_PROCN = 2
                end
            elseif lockInit.ALARM_PROCN == 2 then
                ledOn()
                if tempticks >= (lockInit.AlarmTime*3*16) then
                    ledOff()
                    alarmClose()
                    lockInit.ALARM_LED_FLAG = 0
                end
            else
                edOff()
                alarmClose()
                lockInit.ALARM_LED_FLAG = 0
            end
        else
            lockInit.ALARM_PROCN = 0
            lockInit.ALARM_LED_FLAG = 0
            lockInit.preAlarmTicks = rtos.tick() --重新计时 
            lockInit.preAlarmTotalTicks = rtos.tick() --报警时间计时
            ledOff()
            alarmClose()
        end
    else 
        lockInit.ALARM_PROCN = 0    
        lockInit.ALARM_LED_FLAG = 0
        lockInit.preAlarmTicks = rtos.tick() --重新计时 
        lockInit.preAlarmTotalTicks = rtos.tick() --报警时间计时
        ledOff()
        alarmClose()
    end
end

--蜂鸣器报警判别循环
function alarmLoop()
    local openCloseState = 0 --0:开锁，2：上锁
    if lockInit.PROCN == 0 then 
        openCloseState = 0      --开锁状态
    elseif lockInit.PROCN == 1 then
        openCloseState = 2      --上锁状态
    end

    if openCloseState ~= math.ceil(lockInit.AngleValve/45) then --开关锁状态跟角度不对，则在4S后报警
        if lockInit.alarmFlag == 0 then
            lockInit.alarmFlag = 1
            lockInit.preAlarmTicks1 = rtos.tick()
        elseif (SysTick_GetLapse(lockInit.preAlarmTicks1) >= 4*16384) and (SysTick_GetLapse(lockInit.preAlarmTicks1) < 6*16384) then
            lockInit.ALARM_LED_FLAG = 1 --开启声光提示
        elseif SysTick_GetLapse(lockInit.preAlarmTicks1) > 6*16384 then
            lockInit.ALARM_LED_FLAG = 0 --关闭声光提示
            lockInit.preAlarmTicks1 = rtos.tick()
        else
            --
        end 
    else
        lockInit.alarmFlag = 0
    end
end

--中值平均函数
function MidAveFilter(array,num)
    local min,max,sum=0,0,0
    local i,j,k
    min = array[1]
    for i=1,num do
        if min > array[i] then
            min = array[i]
        end
    end
    max = array[1]
    for j=1,num do
        if max < array[j] then
            max = array[j]
        end
    end
    for k=1,num do
        sum = sum + array[k]
    end
    return math.ceil((sum-max-min)/(num-2))
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
    local voltvalMv = 11*(voltval-(voltval%3))/3    --单位mv
    --发送出的电压数据转换,string.format()格式化转换，将10进制转成16进制字符串
    local voltvalSend = math.ceil(voltvalMv*(0.001/0.01176))
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
    return math.ceil(voltvalMv)
end

--车位有无停车状态检测
--调用串口超声波测距模块测量距离
--上锁状态下周期检测电压
function parkingStatusMeasure()
    --开锁状态下周期检测有无车和电源状态逻辑
    if pio.pin.getval(pio.P0_6) == 0 and pio.pin.getval(pio.P0_7) == 0 then --电机没动作
        if lockInit.AngleValve == 90 then
            if lockInit.electoryPowerMeasureTicks == 0 then --上锁状态1分钟检测一次电压值
                lockInit.electoryPowerMeasureTicks = rtos.tick()
            elseif SysTick_GetLapse(lockInit.electoryPowerMeasureTicks) >= 60*16384 then 
                lockInit.electoryPowerMeasureTicks = 0
                lockInit.VolValueArray[lockInit.VolValueTestCnt] = electoryPowerMeasure()--电压检测
                lockInit.VolValueTestCnt = lockInit.VolValueTestCnt + 1
                if lockInit.VolValueTestCnt>=3 then
                    lockInit.OverCurrProValue = MidAveFilter(lockInit.VolValueArray,3)
                    lockInit.VolValueTestCnt = 1 --重新填入数据
                end 
            end
        else
            lockInit.electoryPowerMeasureTicks = 0
        end

        if lockInit.AngleValve == 0 then             --处于0度开锁状态
            if lockInit.predistanceMeasureTicks == 0 then
                lockInit.predistanceMeasureTicks = rtos.tick()
            end
            lockInit.distanceMeasureTicks = rtos.tick()
            local tempDifference  = lockInit.distanceMeasureTicks - lockInit.predistanceMeasureTicks
            if tempDifference > 147456 and  tempDifference < 163840 then --9~10s之间
                ultrasonicPowerCtrl(1)              --打开超声波电源
            end
            if tempDifference > 163840 then --10s
                if lockInit.distanceMeasureFlag == 0 then    --每个周期只发一次测量请求
                    lockInit.distanceMeasureFlag = 1
                    ultrasonic.write(0x55)
                    log.info("---distance measure require---")
                end
            end
            if tempDifference > 168755 then --10.3s                    
                ultrasonicPowerCtrl(0)              --关闭超声波电源
                lockInit.predistanceMeasureTicks = 0         --周期从新开始
                lockInit.distanceMeasureTicks = 0   
                lockInit.distanceMeasureFlag =0                    
            end
        elseif lockInit.AngleValve == 90 then       --处于90度上锁状态
            ultrasonicPowerCtrl(0)                  --关闭超声波电源
            lockInit.predistanceMeasureTicks = 0             --周期从新开始
            lockInit.distanceMeasureTicks = 0
            lockInit.distanceMeasureFlag =0
        end
    else
        ultrasonicPowerCtrl(0)  --关闭超声波电源
        lockInit.predistanceMeasureTicks = 0 --周期从新开始
        lockInit.distanceMeasureTicks = 0
        lockInit.distanceMeasureFlag =0
    end
end

--获取系统时间与时间点Preticks的差值
function SysTick_GetLapse(Preticks)
    CurTick = rtos.tick()
    return (CurTick > Preticks) and (CurTick-Preticks) or (0xffffffff-Preticks+CurTick)
end

--车位预约开关锁主循环
function ParkingReservationMainLoop()
    --判断是否有远程开关锁指令
    if lockInit.REMOTECMD == 1 then
        if lockInit.AbnormalSign == 1 then --远程开关锁就把异常标志清零
            lockInit.AbnormalSign = 0
        end
        if lockInit.LockStatus == 0 then
            lockInit.PROCN = 20 --远程开锁指令   
        elseif lockInit.LockStatus == 1 then
            lockInit.PROCN = 30 --远程上锁指令
        end 
        lockInit.ALARM_LED_FLAG = 1 --打开声光提示开关锁 
    else 
        if lockInit.LockStatus == 0 then
            -- lockInit.PROCN = 0 --保持开锁
        elseif lockInit.AbnormalSign == 0 then
            lockInit.PROCN = 1 --保持上锁
        elseif lockInit.AbnormalSign == 1 and lockInit.autoLockFlag == 0 then --如果遇到自动上锁
            lockInit.PROCN = 0 --保持开锁
        end
    end
    
    -- if lockInit.AbnormalSign == 1 then
    --     log.info("lock up failed and down","lockInit.PROCN:"..lockInit.PROCN)
    --     --上传一次异常状态
    -- end

    --锁如何动作逻辑功能
    if lockInit.PROCN == 10 then    --任务初始化
        angleMeasure()
        lockInit.AngleValueBffer = lockInit.AngleValve
        lockInit.PROCN = 0
    elseif lockInit.PROCN == 0 then --0度开锁
        -- if lockInit.AbnormalSign == 1 then
        --     log.info("lock up failed and down")
        --     --上传一次异常状态
        -- end
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
                    if lockInit.AbnormalSign == 1 then --自动上锁完成后异常标志位清零
                        lockInit.AbnormalSign = 0
                    end
                    sys.wait(3300) --防止电机转动刚停止就发数据导致摆臂抖动
                    lockInit.autoLockFlag = 0
                    if lockInit.mqttConnectStatusFlag == 1 then
                        mqttOutMsg.pubLockHeartBeat() --自动上锁完成后则上传一次状态
                    end
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
        if lockInit.AngleValve ~= 90 then
            motorUpRunning()
        elseif lockInit.AngleValve == 135 then
            motorDownRunning()
        else 
            motorStopRunning()
            lockInit.PreLockStatus = 1
            lockInit.LockStatus = 1
            lockInit.PROCN = 1 --上锁
        end
        -- lockInit.PreLockStatus = 1
    -- else 
    --     lockInit.LockStatus = 1
    --     lockInit.PreLockStatus = 1
    --     lockInit.PROCN = 1 --上锁
    end 

    --开锁后有停车超过停车时长自动上锁逻辑功能
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
                if (lockInit.preParkingStatus ~= lockInit.ParkingStatus) then
                    log.info("outo lock 3")
                    lockInit.preParkingStatus = 1
                    if lockInit.preHaveCarTicks == 0 then
                        lockInit.preHaveCarTicks = rtos.tick()
                    end
                end

                --记录停车时长用于判断车离后是否自动上锁
                if (lockInit.preHaveCarTicks ~= 0) and SysTick_GetLapse(lockInit.preHaveCarTicks) > (lockInit.AutomaticLockingTime*16384) then
                    log.info("have car time over OpenLockTime")
                    lockInit.preHaveCarTicks = 0
                    lockInit.automaticLockEnable = 1
                end              
            end
        else
            lockInit.PROCN = 0
        end
    end

    --运行时低功耗处理
    angleMeasure()
    if lockInit.AngleValve == 0 or lockInit.AngleValve == 90 then
        if pio.pin.getval(pio.P0_6) == 0 and pio.pin.getval(pio.P0_7) == 0 then  --电机没在动
            --休眠操作     
            if pio.pin.getval(pio.P0_8) == 1 or lockInit.distanceMeasureFlag == 1  then
                --log.info("退出短期休眠")
                pmd.sleep(0)
            else 
                --log.info("进入短期休眠")
                pmd.sleep(1)
            end
        end
    else
        pmd.sleep(0)
    end

    --故障分析处理   
    if lockInit.PROCN == 0 and lockInit.AngleValve == 0 then
        lockInit.tempLockStatusFlag = 0      --正常开锁状态
    elseif lockInit.PROCN == 1 and lockInit.AngleValve == 90 then
        lockInit.tempLockStatusFlag = 1      --正常上锁状态
    else
        lockInit.tempLockStatusFlag = 2      --异常情况（上锁遇阻没到90度，开锁没到0度）
    end

    if lockInit.tempLockStatusFlag ~= lockInit.PROCN then
        if lockInit.PROCN == 1 then --上锁异常
            log.info("SSYC")
            if lockInit.AngleValueBffer == 0 or lockInit.AngleValueBffer == 45 then
                if lockInit.LockProcDifficultTime == 5 then
                    --do nothing    
                elseif (SysTick_GetLapse(lockInit.abnormalTicks)>5*16384) and ( SysTick_GetLapse(lockInit.abnormalTicks)<(lockInit.LockProcDifficultTime*16384 )) then
                    lockInit.ALARM_LED_FLAG = 1 --打开声光提示异常报警
                elseif SysTick_GetLapse(lockInit.abnormalTicks)>(lockInit.LockProcDifficultTime*16384 ) then
                    log.info("SSYZHKS UN")
                    lockInit.PROCN = 0 --异常开锁
                    lockInit.AbnormalSign = 1 --异常标志位置1
                    --异常标志暂时不存进flash
                end
            elseif lockInit.AngleValueBffer == 90 or lockInit.AngleValueBffer == 135 then
                if lockInit.LockStateDifficultTime == 5 then

                elseif SysTick_GetLapse(lockInit.abnormalTicks)>=(lockInit.LockStateDifficultTime*16384 ) then
                    log.info("SSYZHKS DN")
                    lockInit.PROCN = 0 --异常开锁
                    lockInit.AbnormalSign = 1 --异常标志位置1
                    --异常标志暂时不存进flash
                end
            end
        else                        --开锁异常
            lockInit.abnormalTicks = rtos.tick() --异常开始计时
        end
    else
        lockInit.AngleValueBffer = lockInit.AngleValve --记录上一次角度状态
        lockInit.abnormalTicks = rtos.tick()
    end
end

function lockTask()
    statusLedAndAlarm()
    ParkingReservationMainLoop()
    alarmLoop()
    parkingStatusMeasure()
end

--车位锁运行任务
sys.taskInit(
    function()
        lockInit.VolValueArray[1] = electoryPowerMeasure() --上电检测一次供电电压
        lockInit.VolValueArray[2] = lockInit.VolValueArray[1]
        lockInit.VolValueArray[3] = lockInit.VolValueArray[1]
        lockInit.OverCurrProValue = MidAveFilter(lockInit.VolValueArray,3)
        log.info("first running")
        while true do
            lockTask()
            sys.wait(20)
        end
    end
)
