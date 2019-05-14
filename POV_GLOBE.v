
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module POV_GLOBE(

	//////////// CLOCK //////////
	input 		          		CLOCK_50,

	//////////// LED //////////
	output		     [7:0]		LED,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// SW //////////
	input 		     [3:0]		SW,

	//////////// SDRAM //////////
	output		    [12:0]		DRAM_ADDR,
	output		     [1:0]		DRAM_BA,
	output		          		DRAM_CAS_N,
	output		          		DRAM_CKE,
	output		          		DRAM_CLK,
	output		          		DRAM_CS_N,
	inout 		    [15:0]		DRAM_DQ,
	output		     [1:0]		DRAM_DQM,
	output		          		DRAM_RAS_N,
	output		          		DRAM_WE_N,

	//////////// EPCS //////////
	output		          		EPCS_ASDO,
	input 		          		EPCS_DATA0,
	output		          		EPCS_DCLK,
	output		          		EPCS_NCSO,

	//////////// Accelerometer and EEPROM //////////
	output		          		G_SENSOR_CS_N,
	input 		          		G_SENSOR_INT,
	output		          		I2C_SCLK,
	inout 		          		I2C_SDAT,

	//////////// ADC //////////
	output		          		ADC_CS_N,
	output		          		ADC_SADDR,
	output		          		ADC_SCLK,
	input 		          		ADC_SDAT,

	//////////// 2x13 GPIO Header //////////
	inout 		    [12:0]		GPIO_2,
	input 		     [2:0]		GPIO_2_IN,

	//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
	inout 		    [33:0]		GPIO,
	input 		     [1:0]		GPIO_IN
);



//=======================================================
//  REG/WIRE declarations
//=======================================================


//=======================================================
//  Structural coding
//=======================================================

Main main(CLOCK_50, GPIO, KEY);

endmodule
