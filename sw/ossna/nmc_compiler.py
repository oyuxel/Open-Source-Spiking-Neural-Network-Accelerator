import re
import struct

# --- Token Definition ---
class Token:
    def __init__(self, type, value):
        self.type = type
        self.value = value

# --- AST (Abstract Syntax Tree) Nodes ---
class ASTNode: pass
class BinOp(ASTNode):
    def __init__(self, left, op, right):
        self.left = left
        self.op = op
        self.right = right
class Exponent(ASTNode):
    def __init__(self, base, power):
        self.base = base
        self.power = power
class Neg(ASTNode):
    def __init__(self, node):
        self.node = node
class Num(ASTNode):
    def __init__(self, value):
        self.value = value
class Var(ASTNode):
    def __init__(self, name):
        self.name = name
class FuncCall(ASTNode):
    def __init__(self, name, arg):
        self.name = name
        self.arg = arg

# --- Helper Multiplication & Polynomial Functions ---
def is_accumulator(name):
    return name.lower() in ["i_syn", "acc"]

def multiply_expanded_lists(l1, l2):
    result = []
    for t1 in l1:
        for t2 in l2:
            sign = "+" if t1["sign"] == t2["sign"] else "-"
            factors = t1["factors"] + t2["factors"]
            result.append({"sign": sign, "factors": factors})
    return result

def make_poly_ast(coeffs, arg_node):
    node_sum = None
    for power, coeff in enumerate(coeffs):
        if coeff == 0.0:
            continue
        abs_coeff = abs(coeff)
        if power == 0:
            term_node = Num(str(abs_coeff))
        elif power == 1:
            term_node = BinOp(Num(str(abs_coeff)), "*", arg_node)
        else:
            term_node = BinOp(Num(str(abs_coeff)), "*", Exponent(arg_node, power))
        
        if node_sum is None:
            node_sum = Neg(term_node) if coeff < 0 else term_node
        else:
            op = "-" if coeff < 0 else "+"
            node_sum = BinOp(node_sum, op, term_node)
    return node_sum

# --- Symbolic Expansion Engine ---
def expand_ast(node):
    if isinstance(node, Num):
        return [{"sign": "+", "factors": [node.value]}]
    elif isinstance(node, Var):
        return [{"sign": "+", "factors": [node.name]}]
    elif isinstance(node, Neg):
        sub = expand_ast(node.node)
        for term in sub:
            term["sign"] = "-" if term["sign"] == "+" else "+"
        return sub
    elif isinstance(node, Exponent):
        if node.power <= 0:
            return [{"sign": "+", "factors": ["1.0"]}]
        base_expanded = expand_ast(node.base)
        result = base_expanded
        for _ in range(node.power - 1):
            result = multiply_expanded_lists(result, base_expanded)
        return result
    elif isinstance(node, BinOp):
        left_expanded = expand_ast(node.left)
        right_expanded = expand_ast(node.right)
        
        if node.op == "+":
            return left_expanded + right_expanded
        elif node.op == "-":
            for term in right_expanded:
                term["sign"] = "-" if term["sign"] == "+" else "+"
            return left_expanded + right_expanded
        elif node.op == "*":
            return multiply_expanded_lists(left_expanded, right_expanded)
        elif node.op == "/":
            if len(right_expanded) != 1 or len(right_expanded[0]["factors"]) != 1:
                raise SyntaxError("NMC architecture only supports division by a simple constant denominator.")
            denom_name = right_expanded[0]["factors"][0]
            for term in left_expanded:
                term["factors"].append(f"{denom_name}_recip")
            return left_expanded
            
    elif isinstance(node, FuncCall):
        if node.name == "tan":
            raise ValueError(
                "Compiler Error: 'tan(x)' function is not supported in the NMC architecture "
                "due to dynamic Division Rule constraints."
            )
        elif node.name == "exp":
            coeffs = [1.0, 1.0, 0.5, 0.16666667, 0.04166667, 0.00833333]
            poly_ast = make_poly_ast(coeffs, node.arg)
            return expand_ast(poly_ast)
        elif node.name == "sin":
            coeffs = [0.0, 1.0, 0.0, -0.16666667, 0.0, 0.00833333]
            poly_ast = make_poly_ast(coeffs, node.arg)
            return expand_ast(poly_ast)
        elif node.name == "cos":
            coeffs = [1.0, 0.0, -0.5, 0.0, 0.04166667, 0.0, -0.00138889]
            poly_ast = make_poly_ast(coeffs, node.arg)
            return expand_ast(poly_ast)
        elif node.name == "ln":
            coeffs = [0.0, 1.0, -0.5, 0.33333333, -0.25, 0.2]
            x_node = BinOp(node.arg, "-", Num("1.0"))
            poly_ast = make_poly_ast(coeffs, x_node)
            return expand_ast(poly_ast)
        elif node.name == "log10":
            coeffs = [0.0, 1.0, -0.5, 0.33333333, -0.25, 0.2]
            x_node = BinOp(node.arg, "-", Num("1.0"))
            ln_ast = make_poly_ast(coeffs, x_node)
            log10_ast = BinOp(Num("0.43429448"), "*", ln_ast)
            return expand_ast(log10_ast)
        else:
            raise ValueError(f"Compiler Error: Unsupported function name: '{node.name}'")
            
    raise NotImplementedError("Unknown AST node type")

# --- Lexer ---
def tokenize(expr_str):
    token_specification = [
        ('NUMBER',   r'\d+(?:\.\d+)?'),
        ('DBLSTAR',  r'\*\*'),
        ('STAR',     r'\*'),
        ('SLASH',    r'/'),
        ('PLUS',     r'\+'),
        ('MINUS',    r'-'),
        ('LPAREN',   r'\('),
        ('RPAREN',   r'\)'),
        ('IDENT',    r'[a-zA-Z_][a-zA-Z0-9_]*'),
        ('SKIP',     r'[ \t\n]+'),
    ]
    tok_regex = '|'.join('(?P<%s>%s)' % pair for pair in token_specification)
    tokens = []
    for mo in re.finditer(tok_regex, expr_str):
        kind = mo.lastgroup
        value = mo.group()
        if kind == 'SKIP':
            continue
        tokens.append(Token(kind, value))
    return tokens

# --- Parser ---
class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0

    def peek(self):
        if self.pos < len(self.tokens):
            return self.tokens[self.pos]
        return None

    def consume(self, expected_type=None):
        token = self.peek()
        if not token:
            raise SyntaxError("Unexpected end of input.")
        if expected_type and token.type != expected_type:
            raise SyntaxError(f"Expected {expected_type}, got {token.type}")
        self.pos += 1
        return token

    def parse(self):
        return self.expression()

    def expression(self):
        node = self.term()
        while True:
            token = self.peek()
            if token and token.type in ['PLUS', 'MINUS']:
                op_token = self.consume()
                right = self.term()
                node = BinOp(node, op_token.value, right)
            else:
                break
        return node

    def term(self):
        node = self.factor()
        while True:
            token = self.peek()
            if token and token.type in ['STAR', 'SLASH']:
                op_token = self.consume()
                right = self.factor()
                node = BinOp(node, op_token.value, right)
            else:
                break
        return node

    def factor(self):
        node = self.primary()
        token = self.peek()
        if token and token.type == 'DBLSTAR':
            self.consume()
            power_node = self.primary()
            if not isinstance(power_node, Num):
                raise SyntaxError("Exponent value must be an integer literal.")
            node = Exponent(node, int(power_node.value))
        return node

    def primary(self):
        token = self.peek()
        if not token:
            raise SyntaxError("Unexpected end of input inside primary.")
        if token.type == 'NUMBER':
            self.consume()
            return Num(token.value)
        elif token.type == 'IDENT':
            ident_token = self.consume()
            if self.peek() and self.peek().type == 'LPAREN':
                self.consume('LPAREN')
                arg_node = self.expression()
                self.consume('RPAREN')
                return FuncCall(ident_token.value, arg_node)
            else:
                return Var(ident_token.value)
        elif token.type == 'LPAREN':
            self.consume('LPAREN')
            node = self.expression()
            self.consume('RPAREN')
            return node
        elif token.type == 'MINUS':
            self.consume()
            node = self.primary()
            return Neg(node)
        elif token.type == 'PLUS':
            self.consume()
            return self.primary()
        else:
            raise SyntaxError(f"Geçersiz karakter: {token.value}")

def HalfPrecision2Bin(float_num):
    float_num = float(float_num)
    single_precision = struct.pack('>f', float_num)
    single_as_int = struct.unpack('>I', single_precision)[0] 
    sign = (single_as_int >> 31) & 0x1
    exp = (single_as_int >> 23) & 0xFF
    mantissa = single_as_int & 0x7FFFFF
    
    if float_num == 0.0:
        return 0
        
    new_exp = max(0, min(31, (exp - 127 + 15)))
    new_mantissa = mantissa >> 13
    half_precision = (sign << 15) | (new_exp << 10) | new_mantissa
    return half_precision

# --- Temel Yapılar ---
class Neuron:
    def __init__(self, inputs_list=None, param_list=None, const_list=None, body=None, logic=None, dt=None):
        self.Inputs = inputs_list if inputs_list else []
        self.Paramlist = param_list if param_list else []
        self.Constlist = const_list if const_list else []
        self.Body = body if body else []
        self.Logic = logic if logic else ""
        self.dt = dt     # Sayısal entegrasyon zaman adımı (Örn: 0.78125 ms)

class LogicNode:
    def __init__(self, block_type, condition=None, level=0):
        self.type = block_type
        self.condition = condition
        self.statements = []
        self.children = []
        self.parent = None
        self.level = level

# --- Derleyici Sınıfı ---
class NMCCompiler:
    def __init__(self, neuron: Neuron):
        self.neuron = neuron
        self.memory_map = {}
        self.register_map = {}
        self.assembly_code = []
        self.acc_count = 0
        
        self.param_names = []
        self.param_values = {}
        self.const_names = []
        self.const_values = {}
        
        self.optimized_body_equations = []
        self.folded_constant_counter = 0

    @classmethod
    def help(cls):
        help_text = """
================================================================================
                    NMC NEUROMORPHIC COMPILER - HELP GUIDE
================================================================================

1. CONTINUOUS DIFFERENTIAL EQUATIONS (ODE SOLVER)
--------------------------------------------------------------------------------
* You can write continuous ODEs directly in the Body:
  - Form 1: 'dV/dt = RHS'
  - Form 2: 'tau * dV/dt = RHS'
* Time step must be set on the neuron (e.g. neuron.dt = 0.78125).
* The compiler automatically discretizes the equation using Forward Euler into 
  'V_next = V + (dt/tau) * (RHS)', folds all constants, and produces optimized code.

2. MULTI-SYNAPTIC INPUTS
--------------------------------------------------------------------------------
* Pre-synaptic inputs are defined in 'Inputs' list (e.g. ["g_e", "g_i"]).
* Inputs are mapped to the very beginning of the SRAM memory, starting from M(0).
* Note: A neuron must have at least one input defined in 'Inputs'.

3. SUPPORTED MATHEMATICAL OPERATIONS & SYNTAX
--------------------------------------------------------------------------------
* Basic Arithmetic: '+', '-', '*', '/' are fully supported.
* Division Constraint (Division Rule): Dynamic variables CANNOT be used as divisors.
* Exponentiation (**): Any integer power (e.g., 'v**2', 'u**20') is supported.
* Transcendental Functions: exp(x), sin(x), cos(x), ln(x), log10(x) (Taylor series).
* Restrictions: tan(x) is strictly prohibited due to dynamic division limits.

4. LOGIC BLOCK & REFRACTORY PERIOD SYNTAX
--------------------------------------------------------------------------------
* Indentation-based nested-if logic structures are supported.
* Comparison operators: '>', '<', '>=', '<=', '=', '!=', '=='
* Refractory Period Instruction: 'ref_period = N' (where 0 <= N <= 127).
* Inline comments starting with '#' are fully supported.

================================================================================
        NMC Compiler is fully optimized for minimal SRAM & hardware designs.
================================================================================
"""
        print(help_text)

    def parse_assignment(self, item):
        item = item.strip()
        if "=" in item:
            name, val_str = item.split("=", 1)
            name = name.strip()
            val_str = val_str.strip().replace(",", ".")
            try:
                value = float(val_str)
            except ValueError:
                value = 0.0
            return name, value
        return item, 0.0

    def parse_lists_and_extract_values(self):
        self.param_names = []
        self.param_values = {}
        for item in self.neuron.Paramlist:
            name, val = self.parse_assignment(item)
            self.param_names.append(name)
            self.param_values[name] = val

        self.const_names = []
        self.const_values = {}
        for item in self.neuron.Constlist:
            name, val = self.parse_assignment(item)
            self.const_names.append(name)
            self.const_values[name] = val

    def preprocess_differential_equations(self):
        """
        Diferansiyel denklemleri (tau * dV/dt = RHS veya dV/dt = RHS) tarar;
        İleri Euler yöntemiyle sembolik olarak V_next = V + (dt/tau) * (RHS) formuna dönüştürür.
        """
        processed_body = []
        for eq in self.neuron.Body:
            if "=" not in eq:
                processed_body.append(eq)
                continue
            lhs, rhs = eq.split("=", 1)
            lhs_clean = lhs.replace(" ", "")

            # d<Var>/dt veya coeff * d<Var>/dt desenini yakala
            match_ode = re.match(r'^(?:(.*)\*)?\s*d([a-zA-Z_][a-zA-Z0-9_]*)/dt$', lhs_clean)
            if match_ode:
                coeff = match_ode.group(1)
                var = match_ode.group(2)

                if self.neuron.dt is None:
                    raise ValueError(
                        f"Compiler Error: Differential equation detected for '{var}' ('{lhs.strip()}'), "
                        "but time step 'dt' is not defined on the Neuron! (e.g., neuron.dt = 0.78125)"
                    )

                dt_val = float(self.neuron.dt)
                
                # İleri Euler Dönüşümü: X_next = X + (dt / coeff) * (RHS)
                if coeff:
                    discrete_eq = f"{var}_next = {var} + ({dt_val} / {coeff}) * ({rhs.strip()})"
                else:
                    discrete_eq = f"{var}_next = {var} + ({dt_val}) * ({rhs.strip()})"
                
                processed_body.append(discrete_eq)
            else:
                processed_body.append(eq)

        return processed_body

    def optimize_and_fold_constants(self):
        self.parse_lists_and_extract_values()
        self.optimized_body_equations = []
        self.folded_constant_counter = 0

        # Diferansiyel denklemleri otomatik olarak cebirsel fark denklemlerine dönüştür
        effective_body = self.preprocess_differential_equations()

        for eq in effective_body:
            if "=" not in eq:
                continue
            target_var, rhs_expr = eq.split("=")
            target_var = target_var.strip()
            
            tokens = tokenize(rhs_expr)
            parser = Parser(tokens)
            ast_root = parser.parse()
            flat_terms = expand_ast(ast_root)

            optimized_terms = []

            for term in flat_terms:
                sign = term["sign"]
                factors = term["factors"]

                constant_elements = []
                dynamic_elements = []

                for f in factors:
                    if f in self.param_names or f in self.neuron.Inputs:
                        dynamic_elements.append(f)
                    elif f in self.const_names or re.match(r'^-?\d+(?:\.\d+)?$', f):
                        constant_elements.append(f)
                    elif f.endswith("_recip"):
                        base_const = f[:-6]
                        if base_const in self.const_names or re.match(r'^-?\d+(?:\.\d+)?$', base_const):
                            # Erken Sıfıra Bölme Koruması
                            base_val = self.const_values[base_const] if base_const in self.const_names else float(base_const)
                            if base_val == 0.0:
                                raise ZeroDivisionError(
                                    f"Compiler Error: Division by Zero detected. Divisor '{base_const}' has a value of 0.0!"
                                )
                            constant_elements.append(f)
                        elif base_const in self.param_names or base_const in self.neuron.Inputs:
                            raise ValueError(
                                f"Compiler Error: Divisor '{base_const}' is a dynamic variable. "
                                "In NMC architecture, dynamic variables cannot be used as divisors!"
                            )
                        else:
                            raise ValueError(
                                f"Compiler Error: Divisor '{base_const}' is undeclared or invalid!"
                            )
                    else:
                        dynamic_elements.append(f)

                # Constant Folding
                if len(constant_elements) > 1:
                    folded_val = 1.0
                    for elem in constant_elements:
                        if elem.endswith("_recip"):
                            base_const = elem[:-6]
                            base_val = self.const_values[base_const] if base_const in self.const_names else float(base_const)
                            folded_val *= (1.0 / base_val)
                        else:
                            folded_val *= self.const_values[elem] if elem in self.const_names else float(elem)

                    const_name = f"_K{self.folded_constant_counter}"
                    self.folded_constant_counter += 1
                    self.const_names.append(const_name)
                    self.const_values[const_name] = folded_val

                    final_elements = [const_name] + dynamic_elements
                else:
                    final_elements = constant_elements + dynamic_elements

                optimized_terms.append({
                    "sign": sign,
                    "elements": final_elements
                })

            self.optimized_body_equations.append({
                "target": target_var,
                "terms": optimized_terms
            })

    def parse_logic_to_tree(self):
        lines = self.neuron.Logic.split('\n')
        root = LogicNode('root', level=-1)
        current = root

        for line in lines:
            stripped = line.split('#', 1)[0].strip()
            if not stripped:
                continue

            indent = len(line) - len(line.lstrip())

            while current.level >= indent and current.parent is not None:
                current = current.parent

            if stripped.startswith("if "):
                node = LogicNode("if", condition=stripped[3:].strip(), level=indent)
                node.parent = current
                current.children.append(node)
                current = node
            elif stripped.startswith("elsif "):
                node = LogicNode("elsif", condition=stripped[6:].strip(), level=indent)
                node.parent = current
                current.children.append(node)
                current = node
            elif stripped.startswith("else"):
                node = LogicNode("else", condition=None, level=indent)
                node.parent = current
                current.children.append(node)
                current = node
            else:
                current.statements.append(stripped)
        return root

    def get_skip_branches(self, op):
        if op == ">":
            return ["bil", "bie"]
        elif op == ">=":
            return ["bil"]
        elif op == "<":
            return ["big", "bie"]
        elif op == "<=":
            return ["big"]
        elif op in ["=", "=="]:
            return ["big", "bil"]
        elif op == "!=":
            return ["bie"]
        return []

    def compile_statement(self, stmt):
        stmt = stmt.strip()
        if not stmt:
            return []

        insts = []
        if stmt == "spk":
            insts.append("spk")
        elif stmt in ["return", "ret"]:
            insts.append("ret")
        elif stmt.startswith("ref_period") and "=" in stmt:
            _, val_str = stmt.split("=", 1)
            val_str = val_str.strip()
            try:
                val = int(val_str)
            except ValueError:
                raise SyntaxError(f"Compiler Error: Refractory period value must be an integer, got '{val_str}'")
            if not (0 <= val <= 127):
                raise ValueError(f"Compiler Error: Refractory period must be between 0 and 127, got {val}")
            insts.append(f"strf,{val}")
        elif "=" in stmt:
            target_var, expr = stmt.split("=")
            target_var = target_var.strip()
            expr = expr.strip()

            if "+" in expr or "-" in expr:
                op = "+" if "+" in expr else "-"
                v1, v2 = expr.split(op)
                v1, v2 = v1.strip(), v2.strip()

                insts.append("clracc")
                insts.append(f"lw,x2,{self.memory_map[v1]}")
                insts.append("fmac,x2,x1")

                insts.append(f"lw,x2,{self.memory_map[v2]}")
                mnemonic = "fmac" if op == "+" else "smac"
                insts.append(f"{mnemonic},x2,x1")

                insts.append("gacc,x2")
                insts.append(f"sw,x2,{self.memory_map[target_var]}")
            else:
                insts.append(f"lw,x2,{self.memory_map[expr]}")
                insts.append(f"sw,x2,{self.memory_map[target_var]}")
        return insts

    def compile_chain(self, chain):
        compiled_blocks = []
        for i, node in enumerate(chain):
            block_insts = []
            if node.condition:
                match = re.match(r'^([a-zA-Z0-9_]+)\s*(>=|<=|>|<|==|=|!=)\s*([a-zA-Z0-9_]+)$', node.condition)
                if not match:
                    raise SyntaxError(
                        f"Compiler Error: Unsupported or complex condition syntax: '{node.condition}'. "
                        "Only simple binary comparisons are supported."
                    )
                lhs, op, rhs = match.groups()
                block_insts.append(f"lw,x2,{self.memory_map[lhs]}")
                block_insts.append(f"lw,x3,{self.memory_map[rhs]}")
                block_insts.append("comp,x2,x3")

                skip_ops = self.get_skip_branches(op)
                for sk_op in skip_ops:
                    block_insts.append({
                        "type": "skip_branch",
                        "mnemonic": sk_op,
                        "target_block_index": i + 1
                    })

            for stmt in node.statements:
                block_insts.extend(self.compile_statement(stmt))

            nested_chains = self.group_siblings_into_chains(node.children)
            for nc in nested_chains:
                block_insts.extend(self.compile_chain(nc))

            if i < len(chain) - 1:
                block_insts.append("comp,x2,x2")
                block_insts.append({
                    "type": "end_of_chain_branch",
                    "mnemonic": "bie",
                    "target_block_index": len(chain)
                })

            compiled_blocks.append(block_insts)

        flattened_instructions = []
        block_start_indices = []

        for block in compiled_blocks:
            block_start_indices.append(len(flattened_instructions))
            flattened_instructions.extend(block)

        block_start_indices.append(len(flattened_instructions))

        resolved_instructions = []
        for current_idx, inst in enumerate(flattened_instructions):
            if isinstance(inst, dict):
                target_block = inst["target_block_index"]
                target_idx = block_start_indices[target_block]
                offset = target_idx - current_idx
                resolved_instructions.append(f"{inst['mnemonic']},{offset}")
            else:
                resolved_instructions.append(inst)

        return resolved_instructions

    def group_siblings_into_chains(self, children):
        chains = []
        current_chain = []
        for child in children:
            if child.type == "if":
                if current_chain:
                    chains.append(current_chain)
                current_chain = [child]
            else:
                current_chain.append(child)
        if current_chain:
            chains.append(current_chain)
        return chains

    def build_memory_and_registers(self):
        self.optimize_and_fold_constants()

        # Budama (Referans Kontrolü)
        referenced_symbols = set()
        for line in self.neuron.Logic.split('\n'):
            words = re.findall(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', line)
            referenced_symbols.update(words)
            nums = re.findall(r'\b\d+(?:\.\d+)?\b', line)
            referenced_symbols.update(nums)

        for eq in self.optimized_body_equations:
            for term in eq["terms"]:
                for elem in term["elements"]:
                    referenced_symbols.add(elem)

        # 1. INPUTS Adresleme: Her zaman M(0)'dan başlar
        idx = 0
        for inp in self.neuron.Inputs:
            self.memory_map[inp] = idx
            idx += 1

        # 2. 1.0 Sabiti: Girişlerden hemen sonraki adrese kaydırılır
        self.memory_map["1.0"] = idx
        self.register_map["1.0"] = "x1"
        idx += 1

        # Sadece kullanılan dinamik parametreleri ekle
        for param in self.param_names:
            if param in referenced_symbols:
                if param not in self.memory_map:
                    self.memory_map[param] = idx
                    idx += 1

        # Sadece kullanılan sabitleri ekle (Optimizasyon sonucu elenenler yazılmaz)
        for const in self.const_names:
            if const in referenced_symbols:
                if const not in self.memory_map:
                    self.memory_map[const] = idx
                    idx += 1
                recip_name = f"{const}_recip"
                if recip_name in referenced_symbols:
                    if recip_name not in self.memory_map:
                        self.memory_map[recip_name] = idx
                        idx += 1

        # Gövdedeki hedef değişkenleri ekleme
        for eq in self.optimized_body_equations:
            target = eq["target"]
            if target not in self.memory_map:
                self.memory_map[target] = idx
                idx += 1

        has_multi_factor = False
        for eq in self.optimized_body_equations:
            for term in eq["terms"]:
                if len(term["elements"]) >= 3:
                    has_multi_factor = True

        if has_multi_factor:
            self.memory_map["TEMP_ACC"] = idx
            idx += 1

        # Sayısal sabitleri bellek haritasına kaydet (Sıralı literaller ile %100 deterministik build)
        for symbol in sorted(referenced_symbols):
            if re.match(r'^-?\d+(?:\.\d+)?$', symbol):
                if symbol not in self.memory_map:
                    self.memory_map[symbol] = idx
                    idx += 1

    def parse_and_compile_body(self):
        for i, eq in enumerate(self.optimized_body_equations):
            target_var = eq["target"]
            
            # Her yeni denkleme başlarken akümülatörü sıfırla
            if i > 0:
                self.assembly_code.append("clracc")
                
            for signed_term in eq["terms"]:
                sign = signed_term["sign"]
                elements = signed_term["elements"]

                mnemonic = "fmac" if sign == '+' else "smac"

                if len(elements) == 1:
                    elem = elements[0]
                    self.assembly_code.append(f"lw,x2,{self.memory_map[elem]}")
                    self.assembly_code.append(f"{mnemonic},x2,x1")

                elif len(elements) == 2:
                    e1, e2 = elements[0], elements[1]
                    self.assembly_code.append(f"lw,x2,{self.memory_map[e1]}")
                    self.assembly_code.append(f"lw,x3,{self.memory_map[e2]}")
                    self.assembly_code.append(f"{mnemonic},x2,x3")

                else:
                    self.assembly_code.append("gacc,x2")
                    self.assembly_code.append(f"sw,x2,{self.memory_map['TEMP_ACC']}")

                    e1, e2 = elements[0], elements[1]
                    self.assembly_code.append(f"lw,x2,{self.memory_map[e1]}")
                    self.assembly_code.append(f"lw,x3,{self.memory_map[e2]}")

                    self.assembly_code.append("clracc")
                    self.assembly_code.append(f"fmac,x2,x3")

                    for elem in elements[2:]:
                        self.assembly_code.append("gacc,x2")
                        self.assembly_code.append("clracc")
                        self.assembly_code.append(f"lw,x3,{self.memory_map[elem]}")
                        self.assembly_code.append(f"fmac,x2,x3")

                    self.assembly_code.append("gacc,x3")
                    self.assembly_code.append(f"lw,x2,{self.memory_map['TEMP_ACC']}")
                    self.assembly_code.append("clracc")
                    self.assembly_code.append("fmac,x2,x1")
                    self.assembly_code.append(f"{mnemonic},x3,x1")

            self.assembly_code.append("gacc,x2")
            self.assembly_code.append(f"sw,x2,{self.memory_map[target_var]}")

    def generate_memory_image(self):
        num_slots = max(self.memory_map.values()) + 1
        raw_values = [0.0] * num_slots

        # 1. Inputs (Başlangıçta 0.0)
        for inp in self.neuron.Inputs:
            if inp in self.memory_map:
                idx = self.memory_map[inp]
                raw_values[idx] = 0.0

        # 2. 1.0 Constant
        raw_values[self.memory_map["1.0"]] = 1.0

        # 3. Paramlist Assignments
        for param in self.param_names:
            if param in self.memory_map:
                idx = self.memory_map[param]
                raw_values[idx] = self.param_values.get(param, 0.0)

        # 4. Constlist Assignments
        for const in self.const_names:
            val = self.const_values.get(const, 0.0)
            if const in self.memory_map:
                idx = self.memory_map[const]
                raw_values[idx] = val
                
            recip_name = f"{const}_recip"
            if recip_name in self.memory_map:
                recip_idx = self.memory_map[recip_name]
                if val == 0.0:
                    raise ZeroDivisionError(
                        f"Compiler Error: Division by Zero detected. Constant '{const}' has a value of 0.0 and cannot be used as a divisor!"
                    )
                raw_values[recip_idx] = 1.0 / val

        for key, idx in self.memory_map.items():
            if re.match(r'^-?\d+(?:\.\d+)?$', key):
                raw_values[idx] = float(key)

        binary_image = []
        for addr, val in enumerate(raw_values):
            hp_val = HalfPrecision2Bin(val)
            binary_str = f"{hp_val:016b}"
            binary_image.append({
                "address": f"M({addr})",
                "variable": [k for k, v in self.memory_map.items() if v == addr],
                "float_value": val,
                "binary": binary_str
            })
        return binary_image

    def compile(self):
        if not self.neuron.Inputs:
            raise ValueError(
                "Compiler Error: Neuron has no inputs defined. "
                "A neuromorphic neuron must have at least one input defined in 'Inputs'!"
            )
            
        self.build_memory_and_registers()

        self.assembly_code.append("clracc")
        self.assembly_code.append(f"lw,x1,{self.memory_map['1.0']}")

        self.parse_and_compile_body()

        root_node = self.parse_logic_to_tree()
        logic_chains = self.group_siblings_into_chains(root_node.children)

        for chain in logic_chains:
            self.assembly_code.extend(self.compile_chain(chain))

        self.assembly_code.append("ret")

        return "\n".join(self.assembly_code)