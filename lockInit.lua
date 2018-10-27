--- 模块功能：车位锁控制及状态采集任务
-- @author 熊健东
-- @module lock.lockInit
-- @license MIT
-- @copyright lebo
-- @release 2018.10.11

module(...,package.seeall)

require"lockCfg"
require"nvm"

--初始化参数文件
nvm.init("lockCfg.lua")

--读取文件中参数到内存
lockParasTableValue = nvm.get("lockParas")
log.info("lockParas table:",lockParasTableValue["LockDeviceID"],lockParasTableValue["ElectricityADC"],
                            lockParasTableValue["AutomaticLockingTime"],lockParasTableValue["AutomaticLockingTime"],
                            lockParasTableValue["OpenLockTime"],lockParasTableValue["AutoLockTime"])
                            -- lockParasTableValue["AutomaticLockingTime"],lockParasTableValue["AutomaticLockingTime"],
                        
AngleValve     = lockParasTableValue["AngleValve"] 
ElectricityADC = lockParasTableValue["ElectricityADC"]
ParkingStatus  = lockParasTableValue["ParkingStatus"]
LockStatus     = lockParasTableValue["LockStatus"]
PreLockStatus  = lockParasTableValue["PreLockStatus"]
AbnormalSign   = lockParasTableValue["AbnormalSign"]     
LockProcDifficultTime = lockParasTableValue["LockProcDifficultTime"]      --上锁过程中遇阻时间.单位s
LockStateDifficultTime = lockParasTableValue["LockStateDifficultTime"]    --上锁状态遇阻时.单位s
OverCurrProEnable = lockParasTableValue["OverCurrProEnable"]              --1:过流保护启用,0:不启用
OverCurrProPar = lockParasTableValue["OverCurrProPar"]                    --遇阻系数，4，彩虹车位锁比较合适
OverCurrProTime = lockParasTableValue["OverCurrProTime"]                  --过流保护时间，单位s
AlarmLedENABLE = lockParasTableValue["AlarmLedENABLE"]
AlarmTime      = lockParasTableValue["AlarmTime"]
AutomaticLockingTime  = lockParasTableValue["AutomaticLockingTime"]
OpenLockTime = lockParasTableValue["OpenLockTime"] --TMN 启用自动上锁标志且停车超过AutomaticLockingTime后从有车到无车多久自动上锁时长参数
AutoLockTime = lockParasTableValue["AutoLockTime"] --TMC 启用自动上锁标志且开锁后一直无停车多久自动上锁时长参数
LockDeviceID = lockParasTableValue["LockDeviceID"]
GatewayID    =  lockParasTableValue["GatewayID"]


preParkingStatus = 0  --记录上一次有无停车状态
preParkingStatus1 = 0 --记录上一次有无停车状态
AngleValueBffer = 0   --记录角度测量值
AUTO_CLOSE_LOCK_MODE = 1    --自动上锁功能模式标志
OVER_CURR_DETEC_EN   = 1    --遇阻过流保护启用标志
PROCN = 10            --车位锁任务控制标志
REMOTECMD = 0         --远程开关锁响应指令

mqttPubFlag = 0             --记录mqtt发送数据帧标志
mqttHeartBeatSendFlag = 0   --记录mqtt发送锁周期状态
mqttConnectStatusFlag = 0   --记录mqtt连接成功标志
lockActiveFlag = 0          --锁摆臂活动标志
downLockRunTicks = 0        --开锁计时
upLockRunTicks   = 0        --上锁计时

distanceMeasureFlag = 0 --超声波测距标志
distanceMeasureTicks = 0
predistanceMeasureTicks = 0

preOpenLockTimeTicks = 0--开锁后无车多久自动上锁计时起始参数

preHaveCarTicks = 0     --从开锁后，如果有停车开始计时有车时长
automaticLockEnable = 0 --停车超过设置时长自动上锁使能标志

preAutomaticLockTicks = 0
automaticLockCtrlFlag = 0

autoLockFlag = 0

ALARM_LED_FLAG = 0 --声光报警全局标志
ALARM_PROCN = 0    --声光报警逻辑控制标志
preAlarmTicks = 0  
preAlarmTicks1 = 0  
preAlarmTotalTicks = 0
alarmFlag = 0

tempParkingStatusCnt = 0 --记录连续无车或者有车次数

OverCurrProValue = 0     --平均电压值
VolValueTestCnt = 1      --采集周期计步
VolValueArray = {0,0,0}  --电压缓存数组

electoryPowerMeasureTicks = 0 --周期检测电压计时

tempLockStatusFlag = 0
abnormalTicks = 0








