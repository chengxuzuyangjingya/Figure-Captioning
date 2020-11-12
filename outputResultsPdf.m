function outputResultsPdf(paperName, conf)
texFilename = fullfile(conf.resultTexPath,paperName);
sanitizeString = @(str) strrep(strrep(strrep(str, '%', '\%'), 'ﬀ', 'ff'), 'ﬁ', 'fi');

pdfTitle = ['FigureSeer Results for the paper: \url{' sanitizeString(paperName) '}'];

if exist(texFilename, 'file'), delete(texFilename); end
fid = fopen(texFilename, 'w');
fprintf(fid, '\\documentclass[12pt,letterpaper]{article}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage[margin=1in]{geometry}\n');
fprintf(fid, '\\usepackage[pdftex]{hyperref}\n');
fprintf(fid, '\\usepackage[utf8]{inputenc}\n');
fprintf(fid, '\\usepackage{caption}\n');

fprintf(fid, '\n');
fprintf(fid, '\\date{}\n');    
fprintf(fid, '\\begin{document}\n');
fprintf(fid, '\n');
fprintf(fid, '\\title{%s}\n', pdfTitle);
fprintf(fid, '\n');

fprintf(fid, '\\maketitle\n');
fprintf(fid, '\n');
fprintf(fid, '\\tableofcontents\n');
fprintf(fid, '\n');


GRAPHIC_SIZE = 'height=0.3\paperheight,width=0.8\linewidth,keepaspectratio';

figureFiles = dir(fullfile(conf.figureImagePath, sprintf('%s-*.png',paperName)));
%  sprintf('%f',length(figureFiles))
if isempty(figureFiles)
    fprintf('No figures detected');
    fclose(fid);
    return;
end
paperJson = loadjson(fullfile(conf.figureExtractionOutput, [paperName '.json']));
%判断这张图类型是否是Figure,因为有Table类型
%isFig = cellfun(@(js) strcmp(js.Type, 'Figure'), paperJson);
figNums = {};
for n = 1:length(paperJson)  %paperjson表示提取出来的表，图
    json = paperJson{n};  %表示对应的图表的json文件
%    disp(mat2str(json.Number))
%    disp(length(mat2str(json.Number)))
    if length(mat2str(json.Number)) == 1
        figNum = strcat(json.Type, '0', mat2str(json.Number));
        figNums = [figNums;figNum];
    else
        figNum = strcat(json.Type, mat2str(json.Number));
        figNums = [figNums;figNum];
    end
    
end

%figNums = cellfun(@(js) strcat(js.Type, '0', mat2str(js.Number)), paperJson, 'UniformOutput', false);
%disp(figNums)
%figNums(~isFig) = nan;
fprintf(fid, ['\\section{ Figure/Subfigure Extraction Results }\n']);
subfigureFiles = dir(fullfile(conf.subfigureVisPath, sprintf('%s*.png',paperName)));
fprintf(fid, 'Black boxes indicate the figure extracted. Red boxes indicate the extent of the subfigures detected within it. Extracted captions are shown below figures.');
fprintf(fid, '\n\n\\vspace{10mm}\n');

for n = 1:length(subfigureFiles)
    filename = subfigureFiles(n).name;
    resultFignum = strsplit(filename,'-');

    resultFignum = strsplit(resultFignum{end},'.');

    resultFignum = resultFignum{1};
    disp(figNums)
    disp(resultFignum)
    figIdx = find(strcmp(figNums, resultFignum));
    try
        assert(length(figIdx) == 1, 'Incorrect number of matching figure numbers found'); 
    catch
        result.error = 'The figure in two page';
        continue;
    end
    
    caption = paperJson{figIdx}.Caption;
    fprintf(fid,'\\begin{minipage}{\\textwidth}\n');
    fprintf(fid,'\\begin{center}');
    fprintf(fid, ['\\includegraphics[%s]{' fullfile(conf.subfigureVisPath,filename) '}\n\n'], GRAPHIC_SIZE);
    fprintf(fid,'\\end{center}');
    fprintf(fid, 'Original caption: \\begin{it}%s\\end{it} \n\n', sanitizeString(caption));
    fprintf(fid,'\\end{minipage}\n');
    fprintf(fid, '\n\\vspace{10mm}\n');
end


% 图片分类部分
fprintf(fid, ['\\section{Figure Classification Results}\n']);

values = {'Bar Chart', 'Graph Plot', 'Node Diagram', 'Other', 'Scatterplot', 'Table', 'Equation'};
keys = 0:(length(values)-1);
idxToClass = containers.Map(keys,values);

figureImages = dir(fullfile(conf.figureImagePath, sprintf('%s*.png',paperName)));
figureNames = arrayfun(@(f) f.name(1:end-4), figureImages, 'UniformOutput', false);
isSubfigure = @(filename) (length(filename) > 7) && strcmp(filename(end-7:end-2),'subfig');
subfigures = cellfun(isSubfigure, figureNames);
if conf.extractSubfigures
    figureNames = figureNames(subfigures);
else
    figureNames = figureNames(~subfigures);
end
for n = 1:length(figureNames)
    figureName = figureNames{n};
    classificationFilename = fullfile(conf.classPredictionPath, [figureName '.json']);
    classProbs = loadjson(classificationFilename);
    [sortedProbs, order] = sort(classProbs, 'descend');
    if conf.extractSubfigures
        resultFignum = str2double(figureName(end-10:end-9));
        resultSubfignum = str2double(figureName(end-1:end));
    else
        resultFignum = str2double(filename(end-1:end));
    end
    fprintf(fid,'\\begin{minipage}{\\textwidth}\n');
    fprintf(fid,'\\begin{center}');
    fprintf(fid, ['\\includegraphics[%s]{' fullfile(conf.figureImagePath,[figureName '.png']) '}'], GRAPHIC_SIZE);
    fprintf(fid,'\\end{center}');
    fprintf(fid, '\n');
    fprintf(fid, '\\textbf{Figure %d', resultFignum);
    nSubfigures = length(dir(fullfile(conf.figureImagePath, sprintf('%s-fig%.2d-subfig*.png', paperName, resultFignum))));
    if conf.extractSubfigures && nSubfigures > 1
        fprintf(fid, ', Subfigure %d', resultSubfignum);
    end
    fprintf(fid, ' of the paper}\n\n');
    fprintf(fid, 'Predicted Class: \\textbf{%s}\n\n', idxToClass(order(1)-1)); 


    %因为table用折线图解析会有问题，所以将折线图集合在一个文件夹中
%    if strcmp(idxToClass(order(1)-1),'Graph Plot')
    %    fprintf(fid,'%s',fullfile(conf.figureImagePath,[figureName '.png']))
%        img = imread(fullfile(conf.figureImagePath,[figureName '.png']))
%        imwrite(img,fullfile('~/wutlab/figureseer/data/intermediate/graphplot',[figureName '.png']))
    
%    end
    fprintf(fid, 'Probabilities:\n\n');
    for n = 1:length(sortedProbs)
        fprintf(fid, '%.4f %s\n\n', sortedProbs(n), idxToClass(order(n)-1));
    end
    fprintf(fid,'\\end{minipage}\n');
    fprintf(fid, '\n\\vspace{10mm}\n');
end


fprintf(fid, ['\\section{Figure Analysis Results}\n']);
fprintf(fid, '\\vspace{.1mm}');
% show montage that's already generated
resultFiles = dir(fullfile(conf.resultImagePath, sprintf('%s-fig*.png', paperName)));
nResults = 0;
%sprintf('%d',length(resultFiles))
for n = 1:length(resultFiles)
    filename = resultFiles(n).name;
    if conf.extractSubfigures
        resultFignum = str2double(figureName(end-10:end-9));
        resultSubfignum = str2double(figureName(end-1:end));
        classificationFilename = fullfile(conf.classPredictionPath, sprintf('%s-fig%.2d-subfig%.2d.json', paperName, resultFignum, resultSubfignum));
    else
        resultFignum = str2double(filename(end-1:end));
        classificationFilename = fullfile(conf.classPredictionPath, sprintf('%s-fig%.2d.json', paperName, resultFignum, resultSubfignum));
    end
    classProbs = loadjson(classificationFilename);
    [~, predictedClass] = max(classProbs);
    if predictedClass ~= 2
        continue;
    end
    fprintf(fid,'\\begin{minipage}{\\textwidth}\n');
    fprintf(fid,'\\begin{center}');
    fprintf(fid, ['\\includegraphics[%s]{' fullfile(conf.resultImagePath,filename) '}\n\n'], GRAPHIC_SIZE);
    fprintf(fid,'\\end{center}');
    fprintf(fid, '\\textbf{Figure %d', resultFignum);
    nSubfigures = length(dir(fullfile(conf.figureImagePath, sprintf('%s-fig%.2d-subfig*.png', paperName, resultFignum))));
    if conf.extractSubfigures && nSubfigures > 1
        fprintf(fid, ', Subfigure %d', resultSubfignum);
    end
    fprintf(fid, ' of the paper}\n\n');
    if strfind(filename, 'error')
        fprintf(fid, 'Error: Unable to find two numeric axes\n\n');
    end
    fprintf(fid,'\\end{minipage}\n');
    fprintf(fid, '\n\\vspace{5mm}\n');
    nResults = nResults + 1;
end
if nResults == 0
    fprintf(fid, 'Sorry, no graph plots found\n\n');
end

fprintf(fid, '\\end{document}\n');
fclose(fid);



currdir=pwd;
cd(conf.resultTexPath);
pdflatex = conf.pdflatex;
pdflatexCmd = [pdflatex ' -interaction=nonstopmode ' texFilename];
system(pdflatexCmd);
system(pdflatexCmd);
x = findstr(texFilename,'.');
texFilename = strrep(texFilename,texFilename(x(end):end),'');
system(['mv ' texFilename '.pdf ' conf.resultPdfPath]);
cd(currdir);
end
