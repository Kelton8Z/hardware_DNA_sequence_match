#! /usr/bin/env python3
''' Create the data files for Lab5 '''
import random
from pathlib import Path

def main():
    bdf = None
    pgp = None
    while True:
        choice = print_menu(bdf, pgp)
        if choice == 'BFilename':
            filename = get_menu_filename('nucleotide')
            bdf = BioDataFile(filename)
        elif choice == 'GFilename':
            filename = get_menu_filename('grammar pattern')
            pgp = PatternGrammarParser(filename)
        elif choice == 'BG_Random':
            bdf.random_background()
        elif choice == 'BG_Pattern':
            pattern = get_menu_pattern()
            bdf.pattern_background(pattern)
        elif choice == 'BInsert':
            pattern, address = get_menu_insertion('BGD')
            bdf.insert_pattern(pattern, address)
        elif choice == 'GInsert':
            pattern, address = get_menu_insertion('PGP')
            pgp.insert_pattern(pattern, address)
        elif choice == 'BWriteFile':
            bdf.done()
            bdf = None
        elif choice == 'GWriteFile':
            pgp.done()
            pgp = None
        elif choice == 'Quit':
            break
        else:
            print(f'Unknown menu choice: {choice}')

def print_menu(bdf, pgp):
    ''' NYI: Based on the status of BDF/PGP, write different menu details.'''
    ret_dict = {'0':'Quit', '1':'BFilename', '2':'BWriteFile', 
                '3':'GFilename', '4':'GWriteFile', '5':'BG_Random',
                '6':'BG_Pattern', '7':'BInsert', '8':'GInsert'}
    while True:
        print('-'*75)
        print('Choose one:')
        print('  0: Quit')
        print('  1: Nucleotides: Input a filename')
        print('  2: Nucleotides: Write the data to disk')
        print('  3: Grammar Pattern: Input a filename')
        print('  4: Grammar Pattern: Write the data to disk')
        print('  5: Fill nucleotides with a random selection of GTAC')
        print('  6: Fill nucleotides with a pattern of GTAC')
        print('  7: Put a pattern at some address in nucleotide data')
        print('  8: Put a grammar pattern at some address')
        print('-'*75)
        choice = input()
        if not choice or choice not in '012345678':
            print(f'{choice} is an invalid input.  Choose again')
        else:
            return ret_dict[choice]
            
def get_menu_filename(type):
    ''' What is the filename?'''
    while True:
        filename = input(f'What filename do you want to use for your {type} file?\n>')
        if filename:
            return filename
        print('Empty filenames cause trouble.  Try again.')

def get_menu_pattern():
    ''' Get a background pattern of CTAG.'''
    while True:    
        pattern = input('What pattern of CTAG characters would you like?\n>')
        pattern = pattern.upper()
        errors = False
        for c in pattern:
            if not c in 'ACTG' and not errors:
                print('Your pattern string has characters other than ACTG.')
                print(f'Pattern: {pattern}')
                print('Try again, please.')
                errors = True
        if not errors:
            return pattern

def get_menu_insertion(type):
    while True:
        print('What grammar pattern do you want?')
        pattern = input("Don't forget to put () around numbers.\n>")
        if PatternGrammarParser.is_valid(pattern):
            break
        print('Your pattern does not match the grammar')
        print('Try again, please')
    while True:
        address_str = input('At what HEX address should this go?\n>')
        try:
            address = int(address_str, 16)
            break
        except ValueError:
            print('That address is not a hexadecimal value')
            print('Try again, please.')
    if type == 'BGD':
        ntides = PatternGrammarParser.generate(pattern)
        print(f'Insertion pattern: {ntides}')
        return (ntides, address)
    else:
        pmem = PatternGrammarParser.translate(pattern)
        return (pmem, address)

class PatternGrammarParser:
    ''' Represents the file that will hold the grammar pattern data.
        File is always 4096 elements long.
    '''
    LENGTH = 4096

    def __init__(self, filename):
        if not filename.endswith('.mem'):
            if '.' not in filename:
                filename = filename + '.mem'
        self.filename = filename
        self.memory = ['00'] * PatternGrammarParser.LENGTH
        
    def insert_pattern(self, pmem, address):
        ''' Insert the pattern into the memory.
        
            Arguments: pattern -- a string of grammar characters.
                       address -- an integer
        '''
        data_len = len(pmem)
        self.memory[address:address+data_len] = pmem
        self.memory[PatternGrammarParser.LENGTH:] = []  # in case we went beyond memory

    def done(self):
        rep = {'00':'0', '10':'C', '11':'T', '12':'A', '13':'G', '20':'-',
               '21':'|', '22':'/'}
        path = Path(self.filename)
        with open(path, mode='w') as f:
            print('// Grammar Pattern File', file=f)
            print('// Data is HEXADECIMAL!  Use $readmemh()', file=f)
            for addr in range(PatternGrammarParser.LENGTH):
                n = self.memory[addr]
                rep_str = rep.get(n, '  ')
                print(f'{n} // {addr:4X} {rep_str}', file=f)
    
    @staticmethod
    def is_valid(pattern):
        return pattern.endswith('0')
        
    @staticmethod
    def generate(pattern):
        ''' Given a pattern according to the grammar, create a nucleotide
            string that it would match.  Randomly choose lengths for -nums.
            Randomly choose nucleotides from choices or -.
        '''
        g = []
        i = 0
        while True:
            c = pattern[i]
            if c == '0':
                return ''.join(g)
            if c in 'CTAG':
                g.append(c)
                i += 1
            elif c == '-':
                g.append(random.choice('CTAG'))
                i += 1
            elif c == '|':
                next_two = pattern[i+1:i+3]
                g.append(random.choice(next_two))
                i += 3
            elif c == '/':
                next_three = pattern[i+1:i+4]
                g.append(random.choice(next_three))
                i += 4
            elif c == '(':
                neg = (pattern[i+1] == '-')
                if neg:
                    i += 1
                num = int(pattern[i+1], 16)
                if neg:
                    num = random.randrange(num) + 1 # 1 to num, inclusive
                ntide = pattern[i+3]
                if ntide == '-':
                    for j in range(num):
                        g.append(random.choice('CTAG'))
                else:
                    for j in range(num):
                        g.append(ntide)
                i += 4
            else:
                print(f'Odd character in pattern {c} at index {i}')
                i += 1

    @staticmethod
    def translate(pattern):
        ''' Given a pattern according to the grammar, create the representation
            (i.e. the 6-bit hex values).
            
            Returns: A list of hexadecimal strings
        '''
        dict_vals = {'0':'00', 'C':'10', 'T':'11', 'A':'12', 'G':'13', 
                     '-':'20', '|':'21', '/':'22'}
        g = []
        i = 0
        length = len(pattern)
        while True:
            if i >= length:
                return g
            c = pattern[i]
            if c in '0CTAG-|/':
                val = dict_vals[c]
                g.append(val)
                i += 1
            elif c == '(':
                neg = (pattern[i+1] == '-')
                if neg:
                    i += 1
                num = int(pattern[i+1], 16)
                if neg:
                    val = 64-num
                else:
                    val = num
                val_str = f'{val:X}'.zfill(2)
                g.append(val_str)
                i += 3
            else:
                print(f'Odd character in pattern {c} at index {i}: Ignored')
                i += 1

class BioDataFile:
    ''' Represents the file that will hold the nucleotide data.
        File is always 65536 elements long.
    '''

    def __init__(self, filename):
        if not filename.endswith('.mem'):
            if '.' not in filename:
                filename = filename + '.mem'
        self.filename = filename
        
    def random_background(self):
        self.nucleotides = random.choices(['A','C','T','G'], k=65536)
            
    def pattern_background(self, pattern):
        ''' Create and fill the nucleotides list by  repeating a 
            pattern string over and over.  
            
            Arguments: pattern
                A string of non-zero size.  The only characters allowed
                in the string are the nucleotide letters (ACTG).
        '''
        p_len = len(pattern)
        # add a few extra at the end
        rep_count = 65536 // p_len + 1
        self.nucleotides = list(pattern * rep_count)
        self.nucleotides[65536:] = [] #trim, in case we added too many
        
    def insert_pattern(self, pattern, address):
        ''' Insert the pattern into the list of nucleotides.
        
            Arguments: pattern -- a string of 'CTGA' characters.
                       address -- an integer
        '''
        if not hasattr(self, 'nucleotides'):
            print('Define a background pattern first')
            return
        pattern_len = len(pattern)
        self.nucleotides[address:address+pattern_len] = pattern
        self.nucleotides[65536:] = [] #trim, in case we added too many
    
    def done(self):
        if not hasattr(self, 'nucleotides'):
            print('No nucleotides have been defined')
            print('No file will be written')
            return
        rep = {'A' : '10', 'C' : '00', 'T' : '01', 'G':'11'}
        path = Path(self.filename)
        with open(path, mode='w') as f:
            print('// Nucleotide Data File', file=f)
            print('// Data is BINARY!  Use $readmemb()', file=f)
            for addr in range(65536):
                n = self.nucleotides[addr]
                print(f'{rep[n]} // {addr:4X} {n}', file=f)

if __name__ == "__main__":
    main()