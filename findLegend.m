function [legendEntries, cleanedImage] = find_legend(fig, xAxisTextIndices, yAxisTextIndices, legendClassifier)
% legendEntries is a list of the variables in the legend and their symbols
% cleanedImage is the figure image with legend symbols whited out
% cleanImage是带有图例符号的图像
%size后面参数为2 返回列值即宽度，1则是返回行数即高度
figWidth = size(fig.image,2);
figHeight = size(fig.image,1);
% 该子图所对应的json文件共有多少个textbox
nTextBoxes = length(fig.textBoxes);

% Generate features for each text box
figTextFeats = [];
for n = 1:nTextBoxes
    % Position features
    feats = table();
    textBox = fig.textBoxes{n};
% textBox表示json文件中每一个大括号的内容，textBox.box(1)则表示大括号中box属性的第一个值，即x1坐标,(3)表示这个box的宽度

% xposition表示的是这个 textBox中心所在位置的x,yposition表示的是中心的y
    xPosition = textBox.box(1)+textBox.box(3)/2;
    yPosition = textBox.box(2)+textBox.box(4)/2;

%feats.xPos表示所在相对大图的百分比
    feats.xPos = xPosition/figWidth;
    feats.yPos = yPosition/figHeight;

    
    % Text features
    feats.stringLength = length(textBox.text);

%feats.isNumeric表示box中的text是否为数字，是为1，否为0
    feats.isNumeric = ~isnan(str2double(strrep((textBox.text),'%','')));
    % Nearby textbox features
    % tb.box(1)为x1,tb.box(3)为w  tb.box(2)为y1,tb.box(4)为h
    sameColumn = cellfun(@(tb) tb.box(1) <= textBox.box(1) && tb.box(1) + tb.box(3) >= xPosition, fig.textBoxes);
%    wha = cellfun(@(tb) tb.box(1) , fig.textBoxes);
%    disp(wha)
    sameRow = cellfun(@(tb) tb.box(2) <= textBox.box(2) && tb.box(2) + tb.box(4) >= yPosition, fig.textBoxes);


    feats.numInCol = sum(sameColumn)-1;
    feats.numInRow = sum(sameRow)-1;
    figTextFeats = [figTextFeats; feats];
    
end

isLegend = predict(legendClassifier,table2array(figTextFeats));
%如果是图例的话，将其标为1，如果不是则标为0
isLegend = strcmp(isLegend,'1');

% 图例text在box中的索引位置如：共有12个box，排第5位
legendIdx = find(isLegend);




% Extract legend symbols 找寻legend符号
[symbols, symbolBbs] = getSymbols(fig, isLegend);  

% symbols存储的是图像，数据格式[0*20*3 unit8] 数字对应颜色。symbolBbs存储的是double类型数据，是unit8转换而来,为了图像计算

% double类型的图像数据位于0，1之间，0为黑色，1为白色
emptySymbolVec = cellfun(@isempty, symbolBbs);
allWhiteSymbolVec = cellfun(@(symbol) all(symbol(:)==255), symbols);
validSymbolIndices = ~emptySymbolVec & ~allWhiteSymbolVec;
% 有效的符号索引所在不是空的符号向量，也不是全白的符号向量
legendIdx = legendIdx(validSymbolIndices);
cleanedImage = fig.image;
if isempty(legendIdx)
    legendEntries = [];
    return
end
symbols = symbols(validSymbolIndices);
symbolBbs = symbolBbs(validSymbolIndices);

legendEntries(length(symbols)) = LegendEntry();
for n = 1:length(symbols)
%    disp(n)
    index = legendIdx(n);
    label = fig.textBoxes{index}.text;
%    disp(label)
%    disp('hhhhh')
    legendEntries(n) = LegendEntry(label, index, symbols{n});
    cleanedImage = whiteOutBox(cleanedImage, symbolBbs{n});
end

% 下面是对上面采用的一些方法的介绍
function [finalSymbols, symbolBbs] = getSymbols(fig, isLegend)

% Given a figure and logical vector indicating legend labels, return
% symbols and their bounding boxes.

% 子图中不包含json文件中text的剩余部分。即无文本图片块
noTextImage = fig.image;% 此时的noTextImage是整个子图
for textBox = fig.textBoxes
    noTextImage = whiteOutBox(noTextImage, textBox{1}.box);
end



legendIndices = find(isLegend == 1);
nSymbols = length(legendIndices);
% 预先分配内存
legendSymbolsBb = cell(size(legendIndices));
for symbolNum = 1:nSymbols

% 下面的textBox是确认为是图例text的所属块，symbols存储的是一个大框，图例，以及图例左边和右边划分的可能存在符号的框框
    textBox = fig.textBoxes{legendIndices(symbolNum)};
    heightfactor = 5;
    width = textBox.box(4)*heightfactor;
    symbols.textBb = textBox.box;
    symbols.leftBb = textBox.box + [-width, 0, width-textBox.box(3), 0];
    symbols.rightBb = textBox.box + [textBox.box(3), 0, width-textBox.box(3), 0];

% legendSymbolBb存储的是图例整体框的坐标，里面应包含text和symbol
    legendSymbolsBb{symbolNum} = symbols;
end

% If any connected component of nonwhite pixels has the majority of its
% pixels outside of all symbol boxes, it's probably not part of a symbol.
nonwhite = ~im2bw(noTextImage,1-eps); % All nonwhite pixels are 1
%  bwconncomp在图像中寻找连通的非白像素
nonwhiteCC = bwconncomp(nonwhite);
inBox = @(y,x,box) x>=box(1)&x<=box(1)+box(3)&y>=box(2)&y<=box(2)+box(4);
maxInSymbolBoxes = zeros(size(nonwhiteCC.PixelIdxList));
for symbolNum = 1:nSymbols
    [ys,xs] = cellfun(@(ind) ind2sub(size(nonwhite),ind), nonwhiteCC.PixelIdxList, 'UniformOutput', false); % ind2sub返回等效下标值(x为行下标,y为列下标)
    pctInRightBox = cellfun(@(y,x) mean(inBox(y,x,legendSymbolsBb{symbolNum}.rightBb)), ys, xs);
    pctInLeftBox = cellfun(@(y,x) mean(inBox(y,x,legendSymbolsBb{symbolNum}.leftBb)), ys, xs);
    %maxInSymbolBoxes是将所有的左右pictureInBox结合在一起
    maxInSymbolBoxes = max(maxInSymbolBoxes, max(pctInRightBox, pctInLeftBox));
end
outsidePixelIdxList = nonwhiteCC.PixelIdxList(maxInSymbolBoxes<.5);

for textBox = 1:length(outsidePixelIdxList)
    [ys,xs] = ind2sub(size(nonwhite), outsidePixelIdxList{textBox});
    r = sub2ind(size(fig.image),ys,xs,ones(size(ys)));
    g = sub2ind(size(fig.image),ys,xs,2*ones(size(ys)));
    b = sub2ind(size(fig.image),ys,xs,3*ones(size(ys)));
    noTextImage([r;g;b]) = 255;
end

for symbolNum = 1:nSymbols
    textBox = fig.textBoxes{legendIndices(symbolNum)};
    symbols = legendSymbolsBb{symbolNum};
    heightfactor = 7;
    width = textBox.box(4)*heightfactor;
    symbols.text = imcrop(noTextImage, textBox.box);
    symbols.left = imcrop(noTextImage, symbols.leftBb);
    symbols.right = imcrop(noTextImage, symbols.rightBb);
    legendSymbolsBb{symbolNum} = symbols;
    
end

leftPixelProduct = 1;
rightPixelProduct = 1;
for symbolNum=1:nSymbols
    cursym = legendSymbolsBb{symbolNum};
    leftPixelCount = countNonwhitePixels(cursym.left);
    rightPixelCount = countNonwhitePixels(cursym.right);
    
    if leftPixelCount ~= 0 || rightPixelCount ~= 0
        leftPixelProduct = leftPixelProduct * leftPixelCount;
        rightPixelProduct = rightPixelProduct * rightPixelCount;
    end
end

if leftPixelProduct >= rightPixelProduct  % 如果symbol在左边，方向设置为-1.右边设置为1
    direction = -1;
else
    direction = 1;
end

symbolBbs = cell(size(legendIndices));
croppedSymbols = cell(size(legendIndices));
for symbolNum=1:nSymbols
    if direction == 1
        symbol = legendSymbolsBb{symbolNum}.right;
        symbolBb = legendSymbolsBb{symbolNum}.rightBb;
        disp(symbolBb)
        imwrite(symbol,fullfile('~/wutlab/figureseer/data/pngs/png',[mat2str(length(legendIndices)) mat2str(symbolNum) '.png']))
    else
        symbol = legendSymbolsBb{symbolNum}.left;
        symbol = fliplr(symbol); %fliplr将数组从左向右翻转
        symbolBb = legendSymbolsBb{symbolNum}.leftBb;
        imwrite(symbol,fullfile('~/wutlab/figureseer/data/pngs/png',[mat2str(length(legendIndices)) mat2str(symbolNum) '.png']))
    end
    if(all(symbol(:)==255))
        continue; % Symbol is empty
    end
    % Trim代表Bound，即左边界，右边界，上边界，下边界
    [leftTrim,topTrim,rightTrim,botTrim,croppedSymbols{symbolNum}] = cropSymbol(symbol);
    disp(leftTrim)
    disp(topTrim)
    disp(rightTrim)
    disp(botTrim)
    imwrite(croppedSymbols{symbolNum},fullfile('~/wutlab/figureseer/data/pngs/png1',[mat2str(length(legendIndices)) mat2str(symbolNum) '.png']))
    if direction == 1
        symbolBbs{symbolNum} = symbolBb + [leftTrim-1, topTrim-1, -symbolBb(3)+rightTrim-leftTrim, -symbolBb(4)-topTrim+botTrim];
        disp(symbolBbs{symbolNum})
    else
        % 为什么第一个坐标用了symbolBb(3)，画图就知道，翻转过来画图计算可知
        croppedSymbols{symbolNum} = fliplr(croppedSymbols{symbolNum});
        symbolBbs{symbolNum} = symbolBb + [symbolBb(3)-rightTrim+1, topTrim-1, -symbolBb(3)+rightTrim-leftTrim, -symbolBb(4)-topTrim+botTrim]; %CHECK THIS
        
        disp(symbolBbs{symbolNum})
    end
end


finalSymbols = cell(size(legendIndices));
for symbolNum=1:nSymbols
    if ~isempty(symbolBbs{symbolNum})
        finalSymbols{symbolNum} = imcrop(fig.image, symbolBbs{symbolNum});
% length(legendIndices表示这张图有几个可能的图例)
        imwrite(finalSymbols{symbolNum},fullfile('~/wutlab/figureseer/data/pngs/png2',[mat2str(length(legendIndices)) mat2str(symbolNum) '.png']))
    end
end