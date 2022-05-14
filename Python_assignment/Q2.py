import json
PATH = './movie.json'
SPLIT = 8

f = open(PATH)

data = json.load(f)

length = len(data['movie'])

chunk = length // SPLIT

for i in range(SPLIT):
    json.dump(data['movie'][i*chunk: (i+1)*chunk], open('./json_dump/movie'+str(i+1)+'.json', 'w'), indent=True)