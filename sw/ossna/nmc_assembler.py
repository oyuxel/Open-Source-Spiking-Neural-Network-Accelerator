# ossna/nmc_assembler.py

from typing import List

def NModelAssembler(input_string_array: str) -> List[int]:
    """
    NMC Assembly metin komutlarını ayrıştırır ve her bir komutu 
    16-bitlik (uint16) komut koduna dönüştürerek bir liste olarak döndürür.
    """

    def parse_reg(reg_str: str) -> int:
        """'x2' veya ' x2 ' formatındaki yazımı integer 2 yapar."""
        return int(reg_str.strip().replace('x', ''))

    def lw_binary_from_string(command: str) -> str:
        parts = command.split(',')  
        reg_num = parse_reg(parts[1])
        num = int(parts[2].strip()) 
        reg_bin = format(reg_num, '03b')  
        num_bin = format(num, '09b') 
        binary = f"0001{reg_bin}{num_bin}" 
        return binary[-16:] 

    def sw_binary_from_string(command: str) -> str:
        parts = command.split(',')  
        reg_num = parse_reg(parts[1])
        num = int(parts[2].strip()) 
        reg_bin = format(reg_num, '03b')  
        num_bin = format(num, '09b')  
        binary = f"0010{reg_bin}{num_bin}"  
        return binary[-16:]  

    def fmac_binary_from_string(command: str) -> str:
        parts = command.split(',') 
        reg1_num = parse_reg(parts[1])
        reg2_num = parse_reg(parts[2])
        reg1_bin = format(reg1_num, '03b') 
        reg2_bin = format(reg2_num, '03b') 
        return f"0100{'000000'}{reg1_bin}{reg2_bin}"

    def smac_binary_from_string(command: str) -> str:
        parts = command.split(',')  
        reg1_num = parse_reg(parts[1])
        reg2_num = parse_reg(parts[2])
        reg1_bin = format(reg1_num, '03b')  
        reg2_bin = format(reg2_num, '03b')  
        return f"0101{'000000'}{reg1_bin}{reg2_bin}"

    def clracc_binary_from_string(command: str) -> str:
        return "0110000000000000"  

    def comp_binary_from_string(command: str) -> str:
        parts = command.split(',') 
        reg1_num = parse_reg(parts[1])
        reg2_num = parse_reg(parts[2])
        reg1_bin = format(reg1_num, '03b')  
        reg2_bin = format(reg2_num, '03b') 
        return f"0111{'000000'}{reg1_bin}{reg2_bin}"

    def spk_binary_from_string(command: str) -> str:
        return "1011000000000000" 

    def getacc_binary_from_string(command: str) -> str:
        parts = command.split(',')  
        register_num = parse_reg(parts[1])
        reg_bin = format(register_num, '03b')  
        return f"0011{reg_bin}000000000"

    def return_binary_from_string(command: str) -> str:
        return "1101000000000000" 

    def strf_binary_from_string(command: str) -> str:
        parts = command.split(',')  
        num = int(parts[1].strip())  
        num_bin = format(num, '08b')  
        return f"11100000{num_bin}"

    def to_10bit_signed_bin(num: int) -> str:
        """Negatif ve pozitif zıplama ofsetlerini 10-bit ikiliye çevirir (2's complement)."""
        return format(num & 0x3FF, '010b')

    def bil_binary(num: int) -> str:
        return f"100000{to_10bit_signed_bin(num)}"

    def big_binary(num: int) -> str:
        return f"101000{to_10bit_signed_bin(num)}"

    def bie_binary(num: int) -> str:
        return f"100100{to_10bit_signed_bin(num)}"

    def convert_to_binary(command: str) -> str:
        cmd = command.strip()
        if cmd.startswith('lw'):
            return lw_binary_from_string(cmd)
        elif cmd.startswith('sw'):
            return sw_binary_from_string(cmd)
        elif cmd.startswith('fmac'):
            return fmac_binary_from_string(cmd)
        elif cmd.startswith('smac'):
            return smac_binary_from_string(cmd)
        elif cmd.startswith('clr'):
            return clracc_binary_from_string(cmd)
        elif cmd.startswith('com'):
            return comp_binary_from_string(cmd)
        elif cmd.startswith('spk'):
            return spk_binary_from_string(cmd)
        elif cmd.startswith('get') or cmd.startswith('gacc'):
            return getacc_binary_from_string(cmd)
        elif cmd.startswith('ret'):
            return return_binary_from_string(cmd)
        elif cmd.startswith('str'):
            return strf_binary_from_string(cmd)
        elif cmd.startswith('bil'):
            num = int(cmd.split(',')[1].strip())
            return bil_binary(num)
        elif cmd.startswith('big'):
            num = int(cmd.split(',')[1].strip())
            return big_binary(num)
        elif cmd.startswith('bie'):
            num = int(cmd.split(',')[1].strip())
            return bie_binary(num)
        else:
            raise ValueError(f"Assembler Hatası: Tanımlanamayan komut -> '{command}'")

    # 1. Satır satır ayrıştır
    commands = input_string_array.strip().split('\n')
    instruction_words = []

    # 2. Her geçerli komutu doğrudan 16-bit integer'a dönüştür
    for line in commands:
        cmd = line.strip()
        if cmd and not cmd.startswith('#'):
            bin_str = convert_to_binary(cmd)
            instruction_16bit = int(bin_str, 2) & 0xFFFF
            instruction_words.append(instruction_16bit)

    return instruction_words