# 1. Create a script that will read and parse the given files and remove duplicates using python, then write back into a single CSV
import csv

class ReaderTxt():
    def __init__(self, path, name) -> None:
        self.path = path
        self.result = set()
        self.file_name = name
        self.header = []
    def name_title(self, name) -> str:
        return name.strip().title()

    def phone_format(self, number) -> str:
        return "-".join([number[:3], number[3:6], number[6:]]) if len(number) == 10 else number

    def check_duplicate(self, line):
        if line not in self.result:
            self.result.add(line)
            
    def read_file(self, file_name):
        with open(file_name, 'r') as f:
            self.header = list(next(f).split('\t'))
            for row in f.readlines():
                s = row.split('\t')
                first, last, email, phone, address = self.name_title(s[0]), self.name_title(s[1]), s[2], self.phone_format(s[3]), s[4]        
                self.check_duplicate(tuple([first, last, email, phone, address]))
        f.close()

    def to_csv(self, filename):
        with open(filename+'.csv', 'w') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(self.header)
            writer.writerows(list(self.result))
    
    def run(self):
        self.read_file(self.path)
        self.to_csv(self.file_name)
if __name__ == '__main__':
    file_path1 = './people/people_1.txt'
    reader1 = ReaderTxt(file_path1, 'people_1')
    reader1.run()

    file_path2 = './people/people_2.txt'
    reader2 = ReaderTxt(file_path2, 'people_2')
    reader2.run()
    