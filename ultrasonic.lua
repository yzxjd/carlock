module(...,package.seeall)

require"utils"
require"pm"

--[[
功能需求：
uart按照帧结构接收外围设备的输入，收到正确的指令后，回复ASCII字符串

帧结构如下：
帧头：1字节，0x01表示扫描指令，0x02表示控制GPIO命令，0x03表示控制端口命令
帧体：字节不固定，跟帧头有关
帧尾：1字节，固定为0xC0

收到的指令帧头为0x01时，回复"CMD_SCANNER\r\n"给外围设备
收到的指令帧头为0x02时，回复"CMD_GPIO\r\n"给外围设备
收到的指令帧头为0x03时，回复"CMD_PORT\r\n"给外围设备
收到的指令帧头为其余数据时，回复"CMD_ERROR\r\n"给外围设备
]]


--串口ID,1对应uart1
--如果要修改为uart2，把UART_ID赋值为2即可
local UART_ID = 2
--串口读到的数据缓冲区
local rdbuf = ""

-- --[[
-- 函数名：print
-- 功能  ：打印接口，此文件中的所有打印都会加上test前缀
-- 参数  ：无
-- 返回值：无
-- ]]
-- local function print(...)
-- 	_G.print("test",...)
-- end

--[[
函数名：parse
功能  ：按照帧结构解析处理一条完整的帧数据
参数  ：
		data：所有未处理的数据
返回值：第一个返回值是一条完整帧报文的处理结果，第二个返回值是未处理的数据
]]
local function parse(data)
	if not data then return end	

	-- if not tail then return false,data end	
	-- local cmdtyp = string.byte(data,1)
	-- local body,result = string.sub(data,2,tail-1)
	local head  =string.byte(data,1)
	local data1 = string.byte(data,2)
	local data2 = string.byte(data,3)
	local data3 = string.byte(data,4)
	log.info("data for uart parse:",head,data1,data2,data3)
	if head == 0xff then 
		if data3 == (data1+data2) then
			local havecarRange = (data1*256+data2)
			if (havecarRange > 700) and (havecarRange ~= 10555)   then
				lockInit.ParkingStatus  = 0
			else
				lockInit.ParkingStatus  = 1
			end	

			if tempParkingStatusCnt == 0 and (lockInit.preParkingStatus1 ~= lockInit.ParkingStatus) then
				tempParkingStatusCnt = tempParkingStatusCnt + 1
				lockInit.preParkingStatus1 = lockInit.ParkingStatus
			elseif tempParkingStatusCnt == 1 and (lockInit.preParkingStatus1 == lockInit.ParkingStatus) then
				tempParkingStatusCnt = 0
				lockTask.electoryPowerMeasure()--电压检测
				if lockInit.mqttConnectStatusFlag == 1 then
					mqttOutMsg.pubLockHeartBeat() --自动上锁完成后则上传一次状态
				end
			else
				tempParkingStatusCnt = 0
			end

			log.info("distance measure result="..havecarRange.."mm","ParkingStatus:"..lockInit.ParkingStatus)
		end
	end		
    return true,nil
end

--[[
函数名：proc
功能  ：处理从串口读到的数据
参数  ：
		data：当前一次从串口读到的数据
返回值：无
]]
local function proc(data)
	
	if not data or string.len(data) ~= 4 then return end
	--追加到缓冲区
	rdbuf = rdbuf..data	
	
	local result,unproc
	unproc = rdbuf
	--根据帧结构循环解析未处理过的数据
	while true do
		result,unproc = parse(unproc)
		if not unproc or unproc == "" or not result then
			break
		end
	end

	rdbuf = unproc or ""
end

--[[
函数名：read
功能  ：读取串口接收到的数据
参数  ：无
返回值：无
]]
local function read()
	local data = ""
	--底层core中，串口收到数据时：
	--如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
	--如果接收缓冲器不为空，则不会通知Lua脚本
	--所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
	while true do		
		data = uart.read(UART_ID,"*l")
		if not data or string.len(data) == 0 then break end
		--打开下面的打印会耗时
		--print("read",data,common.binstohexs(data))
		proc(data)
	end
end

--[[
函数名：write
功能  ：通过串口发送数据
参数  ：
		s：要发送的数据
返回值：无
]]
function write(s)
	log.info("testUart.write",s)
	uart.write(UART_ID,s)--.."\r\n")
end

local function writeOk()
    log.info("testUart.writeOk")
end

--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("test")休眠，不会进入低功耗休眠状态
--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("test")后，在不需要串口时调用pm.sleep("test")
pm.wake("ultrasonic")
--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
uart.on(UART_ID,"receive",read)
--注册串口的数据发送通知函数
uart.on(UART_ID,"sent",writeOk)
--配置并且打开串口
uart.setup(UART_ID,9600,8,uart.PAR_NONE,uart.STOP_1)

--如果需要打开“串口发送数据完成后，通过异步消息通知”的功能，则使用下面的这行setup，注释掉上面的一行setup
--uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1,nil,1)
