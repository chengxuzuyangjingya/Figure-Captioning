function figureNames = extractFigures(pdfs, conf, filename)

% Extract figures
figureNames = {};
for p = 1:length(pdfs)
%    x = findstr(pdfs{p},'.');
%    pdfs{p} = strrep(pdfs{p},pdfs{p}(x(1):x(end)-1),'');
    pdf = fullfile(conf.pdfPath, filename, pdfs{p});
    [~, paperName, ~] = fileparts(pdf);
    jsonPath = fullfile(conf.figureExtractionOutput, paperName);
    if exist([jsonPath '.json'], 'file') ~= 2
        cmd = [conf.pdffiguresPath...
               ' -j ' jsonPath...
               ' ' pdf];
        cmd = ['env DYLD_LIBRARY_PATH="" LD_LIBRARY_PATH="" ' cmd]; % Matlab uses an older version of libtiff incompatible with pdffigures, run with clear environment to link libpoppler correctly
        system(cmd);
    end

%   figureExtractions表示这篇文献提取出来的大图（未分割用的pdffigures文献工具）
    try
        figureExtractions = loadjson([jsonPath '.json']);   
    catch
        results.error = 'Error using loadjson';
        return;   
    end    
    
%    isFig = cellfun(@(js) strcmp(js.Type, 'Figure'), figureExtractions);
    for n = 1:length(figureExtractions)
%  extraction表示存储提取出来的单独个体，并不是按文献顺序提取的，最后输出它的编号发现是1，2，4，3.此时并没有实际裁剪，仅仅是扫描出图片具体相关信息
        extraction = figureExtractions{n}; 
        
%        paperName = strcat(name,'-',extraction.Type)
        figureName = sprintf('%s-%s%.02d', paperName, extraction.Type, extraction.Number);
        disp(figureName)
% figureName 是papername-fig01这种存储，最后存到figureNames数组中 imageBox是提取图片的box,imageBB是坐标（x1,y1,x2,y2)
        figureNames = [figureNames {figureName}];
        scaleFactor = conf.dpi/extraction.DPI;
% convertBox是将pdffigures中得到的图片坐标转化为MATLAB处理的坐标格式
        imageBox = scaleBox(convertBox(extraction.ImageBB), scaleFactor);
%    figureImage则是实际裁剪出来的大图
        figureImage = rasterizeFigure(pdf, extraction.Page, imageBox, conf.dpi, conf.pageImagePath);
% 这个imwrite写的是papername-fig01这种图片存储
        imwrite(figureImage, fullfile(conf.figureImagePath, [figureName '.png']));
% convertTextBox是将pdffigures中得到的图片中文字坐标转化为MATLAB处理的坐标格式
        textBoxes = cellfun(@(x) convertTextBox(x, scaleFactor, imageBox) ,extraction.ImageText);
%  textBoxes包含box,text,rotation
        % Filter text boxes containing only whitespace
        textBoxes = textBoxes(arrayfun(@(x) ~all(isstrprop(x.text, 'wspace')), textBoxes));
% joinTextBoxes是joinTextBoxes.m中的函数用于将图中的文字提取出来，最后存在papername-fig01.json文件中
        textBoxes = joinTextBoxes(num2cell(textBoxes));
        savejson('', textBoxes, fullfile(conf.textPath, [figureName '.json']));
    end
end
end

% Convert from pdffigures format to our format
function textBox = convertTextBox(pdffiguresText, scaleFactor, imageBox)
textBox.box = translateBox(scaleBox(convertBox(pdffiguresText.TextBB), scaleFactor), imageBox);
textBox.text = pdffiguresText.Text;
textBox.rotation = pdffiguresText.Rotation;
end

% convert from [x1 y1 x2 y2] (used by pdffigures) to [x1 y1 w h] (used by Matlab)
function box = convertBox(box)
box = box - [0 0 box(1) box(2)];
end

function box = scaleBox(box, scaleFactor)
box = round(scaleFactor*box);
end

% Translate from full-page coordinates to figure coordinates  
function box = translateBox(box, imageBox)
box = box - [imageBox(1)-1 imageBox(2)-1 0 0];
end



