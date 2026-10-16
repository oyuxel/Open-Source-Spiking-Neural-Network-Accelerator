import ast
import re
import math
import numpy as np

class Synapse:
    def __init__(self):
        self.param_list = []
        self.wmax = None
        self.wmin = None
        self.correlation_addressing = ""
        self.correlation_term = ""
        self.correlation_var = ""
        self.correlation_step = None
        self.quant_factor = None
        self.correlation = ""
        self.update_rule = ""
        self.out_shift = 0  

class _DSPMapper:
    def __init__(self, w_ast_1, w_ast_2, param_list, quant_factor, corr_term):
        self.w_ast_1 = w_ast_1
        self.w_ast_2 = w_ast_2
        self.params = param_list
        self.qf = quant_factor
        self.corr_term = corr_term

        c1_int = int(np.round(self.params.get("wmax", 0) / self.qf))
        c2_int = int(np.round(self.params.get("wmin", 0) / self.qf))

        c1_int = max(-128, min(127, c1_int))
        c2_int = max(-128, min(127, c2_int))

        self.constants = {
            "C1": c1_int & 0xFFFF,
            "C2": c2_int & 0xFFFF,
            "C3": 0,
            "C4": 0
        }

        self.mux_config = {
            "DSP1": {"D": "00", "C": "00", "B": "00", "A": "00"},
            "DSP2": {"D": "00", "C": "00", "B": "00", "A": "00"},
            "DSP3": {"D": "00", "C": "00", "B": "00", "A": "00"},
            "DSP4": {"D": "00", "C": "00", "B": "00", "A": "00"}
        }

        self.ctrl_config = {
            "DSP1": {"ALU": "0000", "IN": "00000", "OP": "0110101"},
            "DSP2": {"ALU": "0000", "IN": "00000", "OP": "0010000"}, 
            "DSP3": {"ALU": "0000", "IN": "00000", "OP": "0110101"},
            "DSP4": {"ALU": "0000", "IN": "00000", "OP": "0010000"} 
        }

    def map_to_hardware(self):
        if self.w_ast_1:
            self._analyze_branch_ast(self.w_ast_1, "DSP1", "DSP2", "YOL_1")
        if self.w_ast_2:
            self._analyze_branch_ast(self.w_ast_2, "DSP3", "DSP4", "YOL_2")

    def _analyze_branch_ast(self, root_node, dsp_lut, dsp_lin, branch_type):
        terms = self._split_into_terms(root_node)
        for term_node, sign in terms:
            term_str = ast.unparse(term_node).strip()

            if term_str == 'w':
                self.mux_config[dsp_lut]["C"] = "01"

            elif self._contains_var(term_node, self.corr_term):
                self.mux_config[dsp_lut]["B"] = "10"
                if sign == '-': self.ctrl_config[dsp_lut]["ALU"] = "0011"

                if self._contains_var(term_node, 'wmax'):
                    self.mux_config[dsp_lut]["D"] = "10"
                    self.mux_config[dsp_lut]["A"] = "01"
                    self.ctrl_config[dsp_lut]["IN"] = "01100"
                    self.ctrl_config[dsp_lut]["OP"] = "0110101"
                elif self._contains_var(term_node, 'wmin'):
                    self.mux_config[dsp_lut]["D"] = "01"
                    self.mux_config[dsp_lut]["A"] = "11"
                    self.ctrl_config[dsp_lut]["IN"] = "01100"
                    self.ctrl_config[dsp_lut]["OP"] = "0110101"
                elif self._contains_var(term_node, 'w'):
                    self.mux_config[dsp_lut]["A"] = "01"
                    self.mux_config[dsp_lut]["D"] = "00"
                    self.ctrl_config[dsp_lut]["IN"] = "00000"
                    self.ctrl_config[dsp_lut]["OP"] = "0110101"
                else:
                    self.mux_config[dsp_lut]["A"] = "00" 
                    self.mux_config[dsp_lut]["D"] = "00" 
                    self.ctrl_config[dsp_lut]["IN"] = "00000" 
                    self.ctrl_config[dsp_lut]["OP"] = "0110101" 

            else:
                if sign == '-': self.ctrl_config[dsp_lin]["ALU"] = "0011"

                if isinstance(term_node, ast.BinOp) and isinstance(term_node.op, ast.Mult):
                    left = ast.unparse(term_node.left).strip()
                    right = ast.unparse(term_node.right).strip()
                    const_name = left if right == 'w' else right
                    val = self.params.get(const_name, 0.0)

                    c_reg = "C3" if branch_type == "YOL_1" else "C4"
                    self.constants[c_reg] = self._quantize(val)
                    self.mux_config[dsp_lin]["B"] = "11"
                    self.mux_config[dsp_lin]["A"] = "01" 
                    self.mux_config[dsp_lin]["D"] = "00"
                    self.ctrl_config[dsp_lin]["IN"] = "00000"
                    self.ctrl_config[dsp_lin]["OP"] = "0010101"

                elif term_str in self.params:
                    val = self.params.get(term_str, 0.0)

                    c_reg = "C3" if branch_type == "YOL_1" else "C4"
                    self.constants[c_reg] = self._quantize(val)
                    self.mux_config[dsp_lin]["B"] = "11"
                    self.mux_config[dsp_lin]["A"] = "00" 
                    self.mux_config[dsp_lin]["D"] = "00" 
                    self.ctrl_config[dsp_lin]["IN"] = "00000"
                    self.ctrl_config[dsp_lin]["OP"] = "0010101"

    def _split_into_terms(self, node):
        terms = []
        def _traverse(n, current_sign):
            if isinstance(n, ast.BinOp):
                if isinstance(n.op, ast.Add):
                    _traverse(n.left, current_sign)
                    _traverse(n.right, "+")
                elif isinstance(n.op, ast.Sub):
                    _traverse(n.left, current_sign)
                    _traverse(n.right, "-")
                else:
                    terms.append((n, current_sign))
            else:
                terms.append((n, current_sign))
        _traverse(node, "+")
        return terms

    def _contains_var(self, node, var_name):
        for sub_node in ast.walk(node):
            if isinstance(sub_node, ast.Name) and sub_node.id == var_name:
                return True
        return False

    def _quantize(self, value):
        q = int(np.round(value / self.qf))
        if q > 32767: q = 32767
        elif q < -32768: q = -32768
        return q & 0xFFFF

class SynapseCompiler:
    def __init__(self, synapse: Synapse):
        self.syn = synapse
        self.params = {}
        self.lut = {}
        self.addr_min = 0
        self.addr_max = 0
        self.lut_multiplier = 1.0

        self.vliw_config = {
            "COND_1_SEL": "0101",
            "COND_2_SEL": "0110",
            "TRACE_1_OP": "000",
            "TRACE_1_CONST": 0,
            "TRACE_2_OP": "000",
            "TRACE_2_CONST": 0,
            "OUT_SHIFT": format(self.syn.out_shift, '04b')
        }

        self.w_ast_1 = None
        self.w_ast_2 = None

        self._check_update_rule()
        self._parse_params()

        if self.syn.wmax is None or self.syn.wmin is None:
            raise ValueError("wmax and wmin attributes must be defined.")

        self._parse_update_rule()
        self._extract_lut_multiplier()

        if self.syn.correlation:
            self._check_correlation_requirements()
            self._validate_correlation_ast()
            self._calculate_addressing_limits()
            self._generate_lut()

    def _check_update_rule(self):
        if not self.syn.update_rule or not self.syn.update_rule.strip():
            raise ValueError("update_rule cannot be empty.")

    def _parse_params(self):
        self.params["wmax"] = float(self.syn.wmax)
        self.params["wmin"] = float(self.syn.wmin)
        for param_str in self.syn.param_list:
            if "=" not in param_str:
                raise ValueError(f"Parameter '{param_str}' must contain '='.")
            key, val = param_str.split("=", 1)
            self.params[key.strip()] = float(val.strip())

    def _check_correlation_requirements(self):
        if not self.syn.correlation_step:
            raise ValueError("correlation_step is missing.")
        if not self.syn.correlation_var:
            raise ValueError("correlation_var is missing.")
        if not self.syn.correlation_term:
            raise ValueError("correlation_term is missing.")
        if not self.syn.quant_factor:
            raise ValueError("quant_factor is missing.")

    def _validate_correlation_ast(self):
        try:
            tree = ast.parse(self.syn.correlation)
        except SyntaxError as e:
            raise SyntaxError(f"Syntax error in correlation block: {e}")
        allowed_names = set(self.params.keys()).union({
            self.syn.correlation_var,
            self.syn.correlation_term,
            'exp', 'log', 'sin', 'cos', 'sqrt', 'abs', 'math', 'np'
        })
        for node in ast.walk(tree):
            if isinstance(node, ast.Name):
                if node.id not in allowed_names:
                    raise NameError(f"Undefined variable '{node.id}' found in correlation.")

    def _parse_update_rule(self):
        tree = ast.parse(self.syn.update_rule)
        has_if = False
        for node in tree.body:
            if isinstance(node, ast.If):
                has_if = True
                break
        if not has_if:
            self.vliw_config["COND_1_SEL"] = "0101"
            self.vliw_config["COND_2_SEL"] = "0110"
            self._parse_branch(tree.body, 1)
            return

        if len(tree.body) > 1:
            raise SyntaxError("Only a single 'if' root block is allowed.")

        if_node = tree.body[0]
        self.vliw_config["COND_1_SEL"] = self._get_cond_code(if_node.test)
        self._parse_branch(if_node.body, 1)

        if not if_node.orelse:
            self.vliw_config["COND_2_SEL"] = "0110"
            return

        if isinstance(if_node.orelse[0], ast.If):
            if len(if_node.orelse) > 1 or if_node.orelse[0].orelse:
                raise SyntaxError("Only 'if-else' or 'if-elif' are supported.")
            elif_node = if_node.orelse[0]
            self.vliw_config["COND_2_SEL"] = self._get_cond_code(elif_node.test)
            self._parse_branch(elif_node.body, 2)
        else:
            if self.vliw_config["COND_1_SEL"] == "0000": self.vliw_config["COND_2_SEL"] = "0010"
            elif self.vliw_config["COND_1_SEL"] == "0010": self.vliw_config["COND_2_SEL"] = "0000"
            else: self.vliw_config["COND_2_SEL"] = "0101"
            self._parse_branch(if_node.orelse, 2)

    def _get_cond_code(self, test_node):
        if isinstance(test_node, ast.Compare):
            left = test_node.left.id
            op = type(test_node.ops[0])
            right = test_node.comparators[0].value
            if left == "dt" and op == ast.Gt and right == 0: return "0000"
            if left == "dt" and op == ast.Eq and right == 0: return "0001"
            if left == "dt" and op == ast.Lt and right == 0: return "0010"
            if left == "trace_pre" and op == ast.Eq and right == 0: return "0011"
            if left == "trace_post" and op == ast.Eq and right == 0: return "0100"
        raise SyntaxError("Unsupported hardware condition syntax.")

    def _parse_branch(self, body_nodes, path_num):
        prefix = "TRACE_1" if path_num == 1 else "TRACE_2"
        for node in body_nodes:
            if isinstance(node, ast.Assign):
                target = node.targets[0].id
                if target == "trace_post":
                    raise SyntaxError("trace_post is strictly read-only.")
                if target == "w":
                    if path_num == 1: self.w_ast_1 = node.value
                    else: self.w_ast_2 = node.value
                elif target == "trace_pre":
                    if isinstance(node.value, ast.Constant):
                        self.vliw_config[f"{prefix}_OP"] = "011" if node.value.value == 0 else "100"
                    elif isinstance(node.value, ast.BinOp):
                        op = type(node.value.op)
                        const_val = node.value.right.value
                        self.vliw_config[f"{prefix}_OP"] = "001" if op == ast.Add else "010"
                        self.vliw_config[f"{prefix}_CONST"] = const_val

    def _extract_lut_multiplier(self):
        def _get_factors(n):
            if isinstance(n, ast.BinOp) and isinstance(n.op, ast.Mult):
                return _get_factors(n.left) + _get_factors(n.right)
            return [n]
        mapper = _DSPMapper(self.w_ast_1, self.w_ast_2, self.params, 1, self.syn.correlation_term)
        for ast_tree in [self.w_ast_1, self.w_ast_2]:
            if not ast_tree: continue
            terms = mapper._split_into_terms(ast_tree)
            for term, sign in terms:
                if mapper._contains_var(term, self.syn.correlation_term):
                    factors = _get_factors(term)
                    mult = 1.0
                    for f in factors:
                        f_str = ast.unparse(f).strip()
                        if f_str == self.syn.correlation_term: continue
                        if mapper._contains_var(f, 'w'): continue
                        if f_str in self.params:
                            mult *= self.params[f_str]
                        else:
                            try: mult *= float(f_str)
                            except: pass
                    self.lut_multiplier = mult
                    return

    def _calculate_addressing_limits(self):
        expr = self.syn.correlation_addressing.replace(" ", "")
        tokens = re.findall(r'([+-]?)(w|trace_pre|trace_post)', expr)
        limits = {'w': (-128, 127), 'trace_pre': (0, 255), 'trace_post': (0, 255)}
        for sign, var in tokens:
            vmin, vmax = limits[var]
            if sign == '-':
                self.addr_min -= vmax
                self.addr_max -= vmin
            else:
                self.addr_min += vmin
                self.addr_max += vmax

    def _generate_lut(self):
        func_code = f"import math\nimport numpy as np\ndef _compute({self.syn.correlation_var}, {', '.join(self.params.keys())}):\n"
        for line in self.syn.correlation.strip().split('\n'):
            func_code += f"    {line}\n"
        func_code += f"    return {self.syn.correlation_term}\n"
        local_env = {}
        exec(func_code, globals(), local_env)
        compute_func = local_env['_compute']
        for i in range(self.addr_min, self.addr_max + 1):
            val_in = i * self.syn.correlation_step
            res = compute_func(val_in, **self.params)
            folded_res = res * self.lut_multiplier
            quantized_val = int(np.round(folded_res / self.syn.quant_factor))
            if quantized_val > 127: quantized_val = 127
            elif quantized_val < -128: quantized_val = -128
            self.lut[i] = quantized_val

    def compile_vliw(self, lut_center_addr=0):
        mapper = _DSPMapper(self.w_ast_1, self.w_ast_2, self.params, self.syn.quant_factor, self.syn.correlation_term)
        mapper.map_to_hardware()

        lut_mode = "000"
        if self.syn.correlation_addressing == "trace_post": lut_mode = "001"
        elif self.syn.correlation_addressing == "trace_post - trace_pre": lut_mode = "010"
        elif self.syn.correlation_addressing == "trace_pre - trace_post": lut_mode = "011"
        elif self.syn.correlation_addressing == "w": lut_mode = "100"

        vliw_list = list("0" * 256)

        def set_bits(high, low, val_bin):
            val_bin = val_bin.zfill(high - low + 1)
            for offset, char in enumerate(reversed(val_bin)):
                vliw_list[255 - (low + offset)] = char

        for i, dsp in enumerate(["DSP1", "DSP2", "DSP3", "DSP4"]):
            base = i * 16
            ctrl = mapper.ctrl_config[dsp]
            set_bits(base + 15, base, ctrl["ALU"] + ctrl["IN"] + ctrl["OP"])
            m_base = 64 + (i * 8)
            mux = mapper.mux_config[dsp]
            set_bits(m_base + 7, m_base, mux["D"] + mux["C"] + mux["B"] + mux["A"])

        set_bits(143, 128, format(mapper.constants["C1"], '016b'))
        set_bits(159, 144, format(mapper.constants["C2"], '016b'))
        set_bits(175, 160, format(mapper.constants["C3"], '016b'))
        set_bits(191, 176, format(mapper.constants["C4"], '016b'))

        set_bits(194, 192, self.vliw_config["TRACE_1_OP"])
        set_bits(202, 195, format(self.vliw_config["TRACE_1_CONST"], '08b'))
        set_bits(205, 203, self.vliw_config["TRACE_2_OP"])
        set_bits(213, 206, format(self.vliw_config["TRACE_2_CONST"], '08b'))

        set_bits(229, 214, format(lut_center_addr, '016b'))

        set_bits(232, 230, lut_mode)
        set_bits(236, 233, self.vliw_config["COND_1_SEL"])
        set_bits(240, 237, self.vliw_config["COND_2_SEL"])
        set_bits(244, 241, self.vliw_config["OUT_SHIFT"])

        return "0x" + hex(int("".join(vliw_list), 2))[2:].zfill(64).upper()

    def get_lut_array(self):
        return {
            "address_limits": (self.addr_min, self.addr_max),
            "quant_factor": self.syn.quant_factor,
            "folded_multiplier": self.lut_multiplier,
            "lut_data": self.lut
        }
