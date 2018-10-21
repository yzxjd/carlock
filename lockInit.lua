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
AutomaticLockingTime  = lockParasTableValue["AutomaticLockingTime"]
OpenLockTime = lockParasTableValue["OpenLockTime"] --TMN 启用自动上锁标志且停车超过AutomaticLockingTime后从有车到无车多久自动上锁时长参数
AutoLockTime = lockParasTableValue["AutoLockTime"] --TMC 启用自动上锁标志且开锁后一直无停车多久自动上锁时长参数
LockDeviceID  = lockParasTableValue["LockDeviceID"]


preParkingStatus = 0
AngleValueBffer = 0
AUTO_CLOSE_LOCK_MODE = 1
PROCN = 10      --车位锁任务控制标志
REMOTECMD = 0   --远程开关锁响应指令

mqttPubFlag = 0
mqttHeartBeatSendFlag = 0
lockActiveFlag = 0
lockMotoINStatus = 0
lockMotorOUTStatus = 0

preOpenLockTimeTicks = 0

preHaveCarTicks = 0
automaticLockEnable = 0
automaticLockCtrlFlag1 = 0

preAutomaticLockTicks = 0
automaticLockCtrlFlag = 0

autoLockFlag = 0








