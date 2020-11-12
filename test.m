%pdfs = dir(fullfile('~/wutlab/figureseer/data/pdfs','*.pdf'));
%disp(pdfs)
%len = length(pdfs)
%name = {}
%for p = 1:len
%  disp(pdfs(p).name)
%  pdf = fullfile('~/wutlab/figureseer/data/pdfs',pdfs(p).name);
%  [~, paperName, ~] = fileparts(pdf);
%  disp(paperName)
%end
%for y = 185:-1:1
%  disp(y)
%end

a = struct()
a.b ={char('h1')}
savejson('',a)
for n = 1:length(subfigureFiles)
    filename = subfigureFiles(n).name;
%    resultFignum = str2double(filename(end-5:end-4));
    resultFignum = strsplit(filename,'-');
    resultFignum = strsplit(resultFignum{2},'.');
    resultFignum = resultFignum{1}


  43hang  figNums = cellfun(@(js) strcat(js.Type, '0', mat2str(js.Number)), paperJson, 'UniformOutput', false);
disp(figNums)