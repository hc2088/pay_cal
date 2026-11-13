"""Build the explicitly unverified reference catalog, never a verified policy pack.

Run from repository root. Source MIT notice is redistributed with the asset.
"""
import json
import pathlib
import shutil
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'doc/改版设计/城市配置/全国城市默认参数候选集.json'
data = json.loads(source.read_text())
names = [c['cityName'] for c in data['cities']]
# Foundation/ICU supplies transliteration only, not policy values.
swift = '''import Foundation
let data = FileHandle.standardInput.readDataToEndOfFile()
let names = try JSONSerialization.jsonObject(with: data) as! [String]
let values = names.map { $0.applyingTransform(.toLatin, reverse: false)!.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX")).lowercased() }
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: values))
'''
aliases_file = root / 'tool/city_search_aliases.json'
if aliases_file.exists():
    aliases = json.loads(aliases_file.read_text())
else:
    output = subprocess.run(['swift', '-e', swift], input=json.dumps(names).encode(), capture_output=True, check=True)
    latin = json.loads(output.stdout)
    aliases = {name: value for name, value in zip(names, latin)}
    aliases_file.write_text(json.dumps(aliases, ensure_ascii=False, indent=2)+'\n')

cities = []
for c in data['cities']:
    items = []
    for i in c['items']:
        hf = i['kind'] == 'hf'
        items.append({'kind': i['kind'], 'minBase': i['baseMinCents'], 'maxBase': i['baseMaxCents'],
          'employeeRate': i.get('productDefaultCandidatePpm') if hf else (0 if i['kind'] in ['inj','mat'] else i['employeeRatePpm']),
          'employerRate': i.get('productDefaultCandidatePpm') if hf else i['employerRatePpm'],
          'employeeFixed': i.get('employeeFixedFeeCandidateCents', 0), 'employerFixed': 0,
          'roundingUnit': 1, 'defaultRateMax': i.get('rateMaxCandidatePpm') if hf else None,
          'overridden': False, 'actualBase': None})
    note = '参考年度 '+c['sourceYearLabel']+'。完整有效期、费率、舍入和税前处理待核验。'
    if c['status'] == 'partially_verified':
        note += '部分基数和公积金范围已核验；不代表全年规则已核验。'
    if 'injury_base_missing' in c['qualityFlags']:
        note += '工伤基数缺失，需要填写实际适用范围。'
    if c.get('medicalTierCandidates'): note += '须确认医保档次。'
    if 'ltc' in c['additionalCandidates']: note += '长护险资金来源未确认，未自动额外扣款；如实际另扣，请在固定费用中调整。'
    note += '工伤为行业参考比例；公积金预选参考上限；按分舍入为估算假设。'
    evidence = [e for e in data['fieldEvidence'] if e['cityKey']==c['upstreamKey']]
    links = list(dict.fromkeys([e['sourceUrl'] for e in evidence]+[u for r in c['upstreamSourceReferences'] for u in r['urls'] if isinstance(u,str) and u.startswith(('https://','http://'))]+[data['source']['url']]))
    latin = aliases[c['cityName']]
    search = ' '.join([c['cityName'], c['province'], c['upstreamKey'], latin.replace(' ',''), ''.join(w[0] for w in latin.split())])
    cities.append({'id':c['upstreamKey'],'name':c['cityName'],'province':c['province'],'search':search,
      'yearLabel':c['sourceYearLabel'],'version':'reference-20261106-'+data['source']['commit'][:12],
      'items':items,'sources':links,'note':note,'periods':[], 'tiers':c['medicalTierCandidates']})
assert len(cities)==337 and len({c['id'] for c in cities})==337
out = root / 'assets/policies'
out.mkdir(parents=True, exist_ok=True)
(out/'city_references.json').write_text(json.dumps({'schema':'city-reference-1','verified':False,
  'collectedAt':data['generatedAt'],'source':data['source'],'cities':cities},ensure_ascii=False,separators=(',',':'))+'\n')
shutil.copyfile(root/'doc/改版设计/城市配置/来源/city-salary-LICENSE.txt',out/'CITY_DATA_LICENSE.txt')
print(f'Built {len(cities)} reference entries; no verified rules inferred.')
