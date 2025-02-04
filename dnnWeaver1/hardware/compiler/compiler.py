#!/usr/local/bin/python
import argparse
import json
import caffe_pb2
from google.protobuf.text_format import Merge
from DWlayer import DWlayer, ConvLayer, PoolLayer, FCLayer, ReluLayer, LRNLayer, DWMacroLayer, int_to_bin
import sys
from math import ceil, floor
from openProtoBuf import readProtoBuf
from dw_sim import Simulator
from openProtoBuf_old import readProtoBuf_old

def ceil_a_by_b(a, b):
    return int(ceil(float(a) / b))

#ACCELERATOR_BASE_ADDRESS = "0x08000000"
ACCELERATOR_BASE_ADDRESS = "0x88000000"

class DWNet:
    input_dim = []
    num_layers = 0
    layers = []

    def __init__(self, init_net, num_pe, num_pu, op_width, hardware):
        print("Initializing DW Network")
        print("Network Name:\t\t{0}".format(init_net.name))
        self.num_pe = int(num_pe)
        self.num_pu = int(num_pu)
        self.op_width = op_width
        self.hardware = hardware

        try:
            self.input_dim = init_net.input_shape[0].dim
        except IndexError:
            self.input_dim = init_net.input_dim

        print("Input Dimensions:\t{1} x {2} x {0}".format(
            self.input_dim[1], self.input_dim[2], self.input_dim[3]))

        if len(init_net.layer) == 0:
            ll = init_net.layers
        else:
            ll = init_net.layer

        self.num_layers = len(ll)
        print("Number of Layers:\t{0}".format(len(ll)))

        self.layers = []
        self.macro_layers = []
        self.head = []
        macro_layer = None
        print("")
        for l in ll:
            if l.type.lower() == "convolution":
                curr_layer = ConvLayer(l, self.num_pe, self.num_pu, self.op_width)
            elif l.type.lower() == "pooling":
                curr_layer = PoolLayer(l, self.num_pe, self.num_pu, self.op_width)
            elif l.type.lower() == "innerproduct":
                curr_layer = FCLayer(l, self.num_pe, self.num_pu, self.op_width)
            elif l.type.lower() == "relu":
                curr_layer = ReluLayer(l, self.num_pe, self.num_pu, self.op_width)
            elif l.type.lower() == "lrn":
                curr_layer = LRNLayer(l, self.num_pe, self.num_pu, self.op_width)
            else:
                curr_layer = DWlayer(l, self.num_pe, self.num_pu, self.op_width)

            if "data" in l.bottom:
                curr_layer.input_dim = self.input_dim
                curr_layer.base_data_read_address = int(ACCELERATOR_BASE_ADDRESS, 0)
                curr_layer.base_weight_read_address = int(ACCELERATOR_BASE_ADDRESS, 0)
                curr_layer.get_output_dim()
                self.head.append(DWMacroLayer(curr_layer, self.hardware))
            else:
                curr_layer.input_dim = []
                curr_layer.output_dim = []

            self.layers.append(curr_layer)
            print("")


        # Connect Layers
        for l in self.layers:
            prev_layer = l.prev[0]
            for _l in self.layers:
                if _l.name == prev_layer:
                    if _l.next is not None:
                        _l = _l.next
                    print ("Connecting Prev:{0} and Next:{1}".format(_l.name, l.name))
                    l.prev = _l
                    _l.next = l
                    l.set_input_dim(_l.output_dim)
                    l.get_output_dim()


        # Create Macro Layers
        for ml in self.head:
            self.macro_layers.append(ml)
            print("Head: {0}".format(ml.name))
            l = ml.PE_layer.next
            while l is not None:
                print("Curr layer = {0}".format(l.name))
                curr = self.macro_layers[-1]
                if isinstance(l, ConvLayer) or isinstance(l, FCLayer) or isinstance(l, LRNLayer):
                    print("New macro node {0}".format(l.name))
                    macro_layer = DWMacroLayer(l, self.hardware)
                    curr.next = macro_layer
                    macro_layer.prev = curr
                    self.macro_layers.append(macro_layer)
                elif isinstance(l, PoolLayer) or isinstance(l, ReluLayer):
                    print ("Appending: {0}".format(l.name))
                    macro_layer = self.macro_layers.pop(-1)
                    macro_layer.append(l)
                    self.macro_layers.append(macro_layer)
                l = l.next



        for ml in self.macro_layers:
            print(ml)

    def generate_instruction_binary(self, filename):

        compute_bin = filename + "/pu_controller_bin.vh"
        print("*"*50)
        print("Generating Compute Binary : {0}".format(compute_bin))
        print("*"*50)

        max_layers = 0;
        total_weight_size = 0
        for ml in self.macro_layers:
            total_weight_size += ml.get_weight_mem_size()
            print ("Layer {0} weight size {1}".format(ml.name, ml.get_weight_mem_size()))

        print ("total  weight size {0}".format(total_weight_size))
        base_weight_address = int(ACCELERATOR_BASE_ADDRESS, 0)
        base_data_read_address = base_weight_address + total_weight_size
        weight_offset = 0
        for source_node in self.head:
            source_node.base_data_read_address = base_data_read_address
            source_node.base_weight_read_address = base_weight_address + weight_offset
            weight_offset += source_node.get_weight_mem_size()

        with open(compute_bin, "wb") as b:
            for l in self.macro_layers:
                text_buffer = l.generate_compute_instructions()
                for instruction in text_buffer:
                    b.write(instruction)
                max_layers += len(text_buffer)


        max_rd_mem_entries = 0
        rd_mem_binary = filename + "/rd_mem_controller.vh"
        print("*"*50)
        print("Generating Memory Read Binary : {0}".format(rd_mem_binary))
        print("*"*50)
        with open(rd_mem_binary, 'wb') as b:
            for l in self.macro_layers:
                text_buffer = l.generate_memory_read_binary()
                for instruction in text_buffer:
                    b.write(instruction)
                max_rd_mem_entries += len(text_buffer)

        max_wr_mem_entries = 0
        wr_mem_binary = filename + "/wr_mem_controller.vh"
        print("*"*50)
        print("Generating Memory Write Binary : {0}".format(wr_mem_binary))
        print("*"*50)
        with open(wr_mem_binary, 'wb') as b:
            for l in self.macro_layers:
                text_buffer = l.generate_memory_write_binary()
                for instruction in text_buffer:
                    b.write(instruction)
                max_wr_mem_entries += len(text_buffer)

        param_vh = filename + "/dw_params.vh"
        print("*"*50)
        print("Generating DnnWeaver Parameters : {0}".format(param_vh))
        print("*"*50)
        with open(param_vh, 'wb') as b:
            b.write("`define max_layers {0}\n".format(max_layers-1))
            b.write("`define num_pe {0}\n".format(self.num_pe))
            b.write("`define num_pu {0}\n".format(self.num_pu))
            b.write("\n")
            b.write("`define max_rd_mem_idx {0}\n".format(max_rd_mem_entries-1))
            b.write("`define max_wr_mem_idx {0}\n".format(max_wr_mem_entries-1))

        mmap_txt = filename + "/mmap.txt"
        print("*"*50)
        print("Generating DnnWeaver MMAP : {0}".format(mmap_txt))
        print("*"*50)
        with open(mmap_txt, 'wb') as b:
            b.write("{0}\n".format(len(self.macro_layers)))
            b.write("{0}\n".format(self.num_pe))
            b.write("{0}\n".format(self.num_pu))
            for l in self.macro_layers:
                l_type = None
                if isinstance(l.PE_layer, ConvLayer):
                    l_type = 0
                else:
                    l_type = 1
                b.write("{0}\n".format(l_type))
                b.write("{0} {1} {2} {3} {4}\n".format(l.base_data_read_address, l.input_dim[0], l.input_dim[1], l.input_dim[2], l.input_dim[3]))
                wd = l.PE_layer.get_weight_dim()
                b.write("{0} {1} {2} {3} {4}\n".format(l.base_weight_read_address, wd[0], wd[1], wd[2], wd[3]))
                b.write("{0} {1} {2} {3} {4}\n".format(l.base_data_write_address, l.output_dim[0], l.output_dim[1], l.output_dim[2], l.output_dim[3]))

        mmap_txt = filename + "/tb_mmap.vh"
        print("*"*50)
        print("Generating DnnWeaver Testbench MMAP : {0}".format(mmap_txt))
        print("*"*50)
        with open(mmap_txt, 'wb') as b:
            b.write(int_to_bin(len(self.macro_layers), 324))
            b.write("\n")
            l_type = None
            for l in self.macro_layers:
                if isinstance(l.PE_layer, ConvLayer):
                    l_type = 0
                else:
                    l_type = 1
                b.write(int_to_bin(l_type, 4))
                b.write(int_to_bin(l.base_data_read_address, 32))
                id = l.input_dim
                b.write(int_to_bin(id[0], 32))
                b.write(int_to_bin(id[1], 32))
                b.write(int_to_bin(id[2], 32))
                b.write(int_to_bin(id[3], 32))
                wd = l.PE_layer.get_weight_dim()
                b.write(int_to_bin(l.base_weight_read_address, 32))
                b.write(int_to_bin(wd[0], 32))
                b.write(int_to_bin(wd[1], 32))
                b.write(int_to_bin(wd[2], 32))
                b.write(int_to_bin(wd[3], 32))
                b.write("\n")

    def write_memreq_data(self, filename):

############ MS printing all calculations in file########
        file_dimentions = open("layer_memmap.txt","w")
        mem_weights=0;
        mem_img=0;
        mem_op=0;
        first_layer=0
        total_weight_size = 0
        for ml in self.macro_layers:
            total_weight_size += ml.get_weight_mem_size()
            print ("Layer {0} weight size {1}".format(ml.name, ml.get_weight_mem_size()))

      
        base_weight_address = int(ACCELERATOR_BASE_ADDRESS, 0)
        base_data_read_address = base_weight_address + total_weight_size
        file_dimentions.write(" total_weight_size : {0} \n base_weight_addr {1} \n base_data_read_addr : {2}\n".format(total_weight_size,hex(base_weight_address),hex(base_data_read_address)))
        weight_offset = 0
        rd_offset = 0
        print("Inside funtion write_memreq_data, Writing file layer_memmap.txt, ")
        for l in self.macro_layers:
            in_w = l.PE_layer.input_dim[2]
            in_h = l.PE_layer.input_dim[3]
            in_ch = l.PE_layer.input_dim[1]
            num_pe= l.PE_layer.num_pe
            axi_num_data= l.PE_layer.axi_num_data
            kw= l.PE_layer.kernel_width
            kh= l.PE_layer.kernel_height
            out_ch = l.PE_layer.output_dim[1]
            dw = l.PE_layer.op_width/8
            if isinstance(l.PE_layer, ConvLayer):
                out_w =  l.PE_layer.output_dim[2]/2
                out_h =  l.PE_layer.output_dim[3]/2
                img_size    = 1*ceil_a_by_b(in_w,num_pe)*in_h* ceil_a_by_b(num_pe,axi_num_data) * axi_num_data*in_ch
                weight_size =(ceil_a_by_b((kh*kw),axi_num_data)+1) * axi_num_data * in_ch* out_ch

                if l.next is not None and isinstance(l.next.PE_layer, FCLayer):
                    output_size =(ceil_a_by_b(out_w*out_h*out_ch,num_pe)) *   ceil_a_by_b(num_pe,axi_num_data)* axi_num_data
                else :
                    output_size =(ceil_a_by_b(out_w,num_pe)) *  out_h * ceil_a_by_b(num_pe,axi_num_data)* axi_num_data*out_ch
                num_in_bytes =  img_size * dw
                num_mem_locns =  img_size / axi_num_data
            elif isinstance(l.PE_layer, FCLayer):
                out_w =  l.PE_layer.output_dim[2]
                out_h =  l.PE_layer.output_dim[3]
                img_size    = 1*ceil_a_by_b(in_w*in_h*in_ch,num_pe)*   ceil_a_by_b(num_pe,axi_num_data) * axi_num_data
                weight_size = ceil_a_by_b (out_ch,num_pe)* ceil_a_by_b(num_pe,axi_num_data) * axi_num_data * (in_ch*in_w*in_h+1)
                output_size =(ceil_a_by_b(out_w*out_h*out_ch,num_pe)) *   ceil_a_by_b(num_pe,axi_num_data)* axi_num_data
                num_in_bytes =  img_size * dw
                num_mem_locns =  img_size / axi_num_data
            mem_weights=mem_weights+(weight_size*dw)
            if(first_layer==0):
                first_imgw= img_size*dw
            if(first_layer==1):
                mem_img= mem_img+(img_size*dw)
            mem_op_last=output_size*dw
            file_dimentions.write("********* Layer : {0}*******\n".format(l.PE_layer))
            file_dimentions.write("****************************\n".format(l.PE_layer))
            file_dimentions.write("input dim :{0},output dim: {1}\n".format(l.PE_layer.input_dim,l.PE_layer.output_dim))
            file_dimentions.write("Input Width : {0}, Height : {1} , Num CHannles {2}\n".format(in_w, in_h,in_ch))
            file_dimentions.write("Output Width : {0}, Height : {1} , Num CHannles {2}\n".format(out_w, out_h,out_ch))
            file_dimentions.write("Num PE: {0}, Num AXI transcations: {1}, Kernel wxh: {2}x{3}, opwidth {4} \n".format(num_pe,axi_num_data,kw,kh,dw))
            file_dimentions.write(" "*35)
            file_dimentions.write("\n")
            file_dimentions.write("Input Image Details Mem Requirement:\n")
            file_dimentions.write(" "*35)
            file_dimentions.write("\n")
            if isinstance(l.PE_layer, ConvLayer):
                file_dimentions.write("ImgSize after Padding(ImgSize): ceil_a_by_b(in_w,num_pe)*in_h*ceil_a_by_b(num_pe,axi_num_data)*axi_num_data*in_ch={0}\n".format(img_size))
                file_dimentions.write("Mem Required in Bytes = ImgSize * opwidth={0}\n".format(num_in_bytes))
                file_dimentions.write("Mem Locations (64 bit)= ImgSize /axi_num_data={0}\n".format(num_mem_locns))
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write(" Weight Details Mem Requirement:\n")
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write("Weights Size after Padding(weightSize): (ceil_a_by_b(kw*kh,axi_num_data)+1)*axi_num_data*in_ch*out_ch={0}\n".format(weight_size))
                file_dimentions.write("Mem Required in Bytes = weightSize * opwidth={0}\n".format(weight_size*dw))
                file_dimentions.write("Mem Locations (64 bit)= weightSize /axi_num_data={0}\n".format(weight_size/axi_num_data))
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write(" Output Details Mem Requirement:\n")
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write("Ouput Size after Padding(output_size): (ceil_a_by_b(out_w,num_pe))* out_h * ceil_a_by_b(num_pe,axi_num_data)*axi_num_data*out_ch={0}\n".format(output_size))         
                file_dimentions.write("Mem Required in Bytes = output_size * opwidth={0}\n".format(output_size*dw))
                file_dimentions.write("Mem Locations (64 bit)= output_size /axi_num_data={0}\n".format(output_size/axi_num_data))

                file_dimentions.write("Weights Addr : {0}\n".format(hex(base_weight_address+weight_offset)))
                file_dimentions.write("Read Addr    : {0}\n".format(hex(base_data_read_address+rd_offset)))
                file_dimentions.write("Write Addr   : {0}\n".format(hex(base_data_read_address+rd_offset+num_in_bytes)))
                weight_offset+=weight_size*dw
                rd_offset+= num_in_bytes

            elif isinstance(l.PE_layer, FCLayer):
                file_dimentions.write("ImgSize after Padding(ImgSize): ceil_a_by_b(in_w x in_h x in_ch,num_pe)*ceil_a_by_b(num_pe,axi_num_data)*axi_num_data={0}\n".format(img_size))
                file_dimentions.write("Mem Required in Bytes = ImgSize * opwidth={0}\n".format(num_in_bytes))
                file_dimentions.write("Mem Locations (64 bit)= ImgSize /axi_num_data={0}\n".format(num_mem_locns))
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write(" Weight Details Mem Requirement:\n")
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write("Weights Size after Padding(weightSize):ceil_a_by_b (out_ch,num_pe)* ceil_a_by_b(num_pe,axi_num_data) * axi_num_data * (in_ch*in_w*in_h+1) ={0}\n".format(weight_size))
                file_dimentions.write("Mem Required in Bytes = weightSize * opwidth={0}\n".format(weight_size*dw))
                file_dimentions.write("Mem Locations (64 bit)= weightSize /axi_num_data={0}\n".format(weight_size/axi_num_data))
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write(" Output Details Mem Requirement:\n")
                file_dimentions.write(" "*35)
                file_dimentions.write("\n")
                file_dimentions.write("Ouput Size after Padding(output_size): (ceil_a_by_b(out_w*out_h*out_ch,num_pe)) *   ceil_a_by_b(num_pe,axi_num_data)* axi_num_data={0}\n".format(output_size))
                file_dimentions.write("Mem Required in Bytes = output_size * opwidth={0}\n".format(output_size*dw))
                file_dimentions.write("Mem Locations (64 bit)= output_size /axi_num_data={0}\n".format(output_size/axi_num_data))

                file_dimentions.write("Weights Addr : {0}\n".format(hex(base_weight_address+weight_offset)))
                file_dimentions.write("Read Addr    : {0}\n".format(hex(base_data_read_address+rd_offset)))
                file_dimentions.write("Write Addr   : {0}\n".format(hex(base_data_read_address+rd_offset+num_in_bytes*in_ch)))
                weight_offset+=weight_size*dw
                rd_offset+=num_in_bytes*in_ch
            file_dimentions.write("\n*****************************\n")
            first_layer= 1
        file_dimentions.write("\n*******Total Memory in Bytes*********************\n")
        file_dimentions.write("\n*************************************************\n")
        file_dimentions.write("\nMem Requited for Weightsi : {0}\n".format(mem_weights))
        file_dimentions.write("\nMem Requited for Layer1 Input         : {0}\n".format(first_imgw))
        file_dimentions.write("\nMem for Intermediate Layer Processing : {0} \n".format(mem_img))
        file_dimentions.write("\nMem for Last Layer Output             : {0} \n".format(mem_op_last))
        file_dimentions.write("\nTotal Mem in Bytes /Input image       : {0}B or {1}kB \n".format(mem_weights+mem_img+first_imgw+mem_op_last,(ceil_a_by_b(mem_weights+mem_img+first_imgw+mem_op_last,1024))))
        file_dimentions.write("\nActual Memory allocated (B):             : {0} \n".format((base_data_read_address+rd_offset+output_size*dw)-base_weight_address))
        file_dimentions.close()



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate the instructions for each layer in the network.")
    # parser.add_argument("--fpga", help="FPGA - Xilinx zynq or Altera stratix V.", required=True)
    # parser.add_argument("--debug", help="Enable debug output", action="store_true")
    parser.add_argument("-prototxt", help="Path to network prototxt", required=True)
    parser.add_argument("-binary_folder", help="Path to binary folder for output .vh", required=True)
    parser.add_argument("-num_pe", help="Number of PEs per PU in the accelerator", required=False, default=None, type=int)
    parser.add_argument("-num_pu", help="Number of PU in the accelerator", required=False, default=None, type=int)
    parser.add_argument("-op_width", help="OP width", required=False, type=int, default=16)
    parser.add_argument("-fpga", help="FPGA (zynq, stratix, or arria10)", required=True, type=str)
    args = parser.parse_args()

    if str(args.fpga).lower() == "zynq":
        hardware_file = "./json/zynq.json"
    elif str(args.fpga).lower() == "stratix":
        hardware_file = "./json/stratix.json"
    elif str(args.fpga).lower() == "arria10":
        hardware_file = "./json/arria10.json"
    else:
        print "Unknown FPGA"
        sys.exit(-1)

    hardware = json.loads(open(hardware_file).read())

    if (args.num_pe is None or args.num_pu is None):

        network_json = readProtoBuf(args.prototxt)
        dnn_sim = Simulator(network_json, hardware)
        dnn_sim.combine_layers()
        config = dnn_sim.simulate()

        num_pe = config[0]
        num_pu = config[3] * config[2]

    else:
        num_pe = args.num_pe
        num_pu = args.num_pu

    print("Config = {0} PEs, {1} PUs".format(num_pe, num_pu))

    net = caffe_pb2.NetParameter()
    Merge((open(args.prototxt, 'r').read()), net)

    dwNet = DWNet(net, num_pe, num_pu, args.op_width, hardware)
    dwNet.generate_instruction_binary(args.binary_folder)
    dwNet.write_memreq_data(args.binary_folder)

