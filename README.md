# JESD204B Transport and Data Link Layer

This is my personal project for an implementation of JESD204B transport layer written in Verilog. The information and design is based off JEDEC JESD204B specification, which can be downloaded from [JEDEC](https://www.jedec.org/sites/default/files/docs/JESD204B.pdf) website.

## About JESD204B

This is a serialized interface between data converters (ADC/DAC) and logic devices (FPGA/ASIC). To further understand, this device specification has been divided into layers, including Application Layer, Transport Layer, Data Link Layer and Physical Layer. This repository will focus on the Transport Layer, the optional Scramber/Descrambler block and the 8B/10B Encode in the Data Link Layer. Note that, there are still more to the Data Link Layer which deals with synchronization and alignment, but those are not discussed here.

## JESD204B Transport Layer

The main purpose of JESD204B transport layer is to pack data (Transmitter, Tx) or unpack it (Receiver, Rx) based on link configurations:
*	It can add more information (control bits) about the transmitted data
*	For Tx: It arranges data into octets, then into frames, before sending it as parallel data to data link layer
*	For Rx: It collects data from each frame and lane, before sending it to the back-end data processing stage

The configuration is determined in the application layer in the Tx, and will be passed to the transport layer as Verilog 'parameters' during module instantiation.

### Design Specification

The parameters that should be decided in application layer include L, M, N, N', CS, S (# of lanes, converters, resolution, sample size, control bits, samples). Further interpretation of this can be found in JEDEC specification. My design will determine TT (# of tail bits) and F (# of octets per frame) based on those configuration. 

For Tx, input data from converters are assumed to be concatenated, with least significant #resolution bits represents data from converter 0. Output data from lanes are also concatenated into 1 single bus, with least significant bits represents lane 0. The reverse is true for Rx devices.

### Key Features

This design of JESD204B Transport Layer supports these following configurations. Note that all of them have been and can be tested by changing the parameter in the testbench file:
* Support 1-8 converters
* Support converter resolution of 10-16 bits
* Support 1-8 lanes
* Support 0-3 controls bits 

Odd input parameters for lanes and converters are also supported. Lanes that are not entirely filled with samples will be filled with TT (tail bits) instead.  

Converter resolution of 1-9 bits is supported as well, but it is usually not the case for a converter to have those resolutions. Therefore, they are omitted. 

### Constraints

The design assumes the sample size is 16 and each converter produces 1 sample per cycle for each frame, which is often to be the case. This limits the parameter of SAMPLE_SIZE and SAMPLES to be 16 and 1, though it can be changed in the code. Furthermore, due to these 2 constraints, values we pick for other parameters need to follow this rule:
* (Converter resolution + Control bits) ≤ 16
* L (# of lanes) ≤ M (# of converters)

## JESD204B Scrambler/Descrambler

Scrambler is brought to use in the case when the data octet repeats from frame to frame, which would lead to spectral leaks causing electromagnetic interference in sensitive devices. There are many other advantages of using a scrambler, however, it can lead to some downsides which is why the choice of using a scrambler is totally optional. 

JESD204 scrambler is designed based on the polynomials ![equation](https://latex.codecogs.com/gif.latex?%5Cinline%20%5Cdpi%7B100%7D%20%5Cbg_black%20%5Cfn_phv%201&plus;x%5E%7B14%7D&plus;x%5E%7B15%7D), and is of the self-synchronous type. I chose to use the serial implementation of the scrambler, of which 1 bit is scrambled at a time but the whole input would still finish in 1 clock cycle. This is different from the parallel implementation but would still lead to the same result. Further details are explained in the pdf.

## JESD204B 8B/10B Encoder/Decoder

The 8B/10B Encoding is a process to encode data (before transmitted) that allows clock recovery and is DC-balanced. Further details on this can be viewed in another repository of mine [here](https://github.com/Anthon1e/8B-10B-Encoder-Decoder). However, in that implementation I have only created a general 8B10B encoder/decoder. For the purpose of JESD204B design and data flow here I have made some changes to the file.

## Reference 

South Arlington. *JEDEC STANDARD: Serial Interface for Data Converters.* [Online] 2011. Available from: https://www.jedec.org/sites/default/files/docs/JESD204B.pdf

Texas. *JESD204B Overview: Texas Instruments High Speed Data Converter Training.* [Online] 2016. Available from: https://www.ti.com/lit/pdf/slap161
