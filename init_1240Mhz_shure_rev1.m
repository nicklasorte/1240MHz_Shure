close all;
close all force;
clc;
app=NaN(1);  %%%%%%%%%This is to allow for Matlab Application integration.
format shortG
top_start_clock=clock;
folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\1.3GHz Shure';
cd(folder1)
addpath(folder1)
pause(0.1)
addpath('C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\Basic_Functions')
addpath('C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\General_Terrestrial_Pathloss') 
pause(0.1)





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%LRR System 2: PLACEHOLDER Inputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rx_ant_heigt_m=10; %%%%%%meters
rx_nf=2;  %%%%%%%NF in dB
rx_ant_gain_mb=41; %%%%%%Main Beam gain in dBi
in_ratio=-10; %%%%%I/N Ratio
tx_bw_mhz=0.7; %%megahertz: Have EIRP in this bandwidth.: Might need to apply FDR co-channel since tx bw is larger than rx bw.[Just assuming both are same]
rx_bw_mhz=0.7; %%%%%Megahertz
fdr_dB=10*log10(tx_bw_mhz/rx_bw_mhz) %%%%%Example placeholder
radar_threshold=-174+10*log10(rx_bw_mhz*10^6)+rx_nf+in_ratio  %%%%%%%
dpa_threshold=floor(radar_threshold-rx_ant_gain_mb+fdr_dB)  %%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%Other Inputs
rev=1
tx_height_m=2; %%%%%%2 meters
max_itm_dist_km=50;
reliability=50%
FreqMHz=1240;
tf_clutter=1
tx_eirp=24 %%%%%%%24dBm/1mhz [???] Might need to apply FDR co-channel since tx bw is larger than rx bw.
required_pathloss=ceil(tx_eirp-dpa_threshold) %%%%%%%%%%%%%%%%%Round up
%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%Find the ITM Area Pathloss for the distance array
tic;
max_rx_height=rx_ant_heigt_m
[array_dist_pl]=itm_area_dist_array_sea_rev2(app,reliability,tx_height_m,max_rx_height,max_itm_dist_km,FreqMHz);
toc;
tic;
save(strcat('Rev',num2str(rev),'_array_dist_pl.mat'),'array_dist_pl')
toc;

%%%%%%%%%%Adding clutter
[array_clutter]=clutter_p2108_50(app,FreqMHz);

%%%%%%%
nn_idx=nearestpoint_app(app,array_dist_pl(:,1),array_clutter(:,1));
array_pathloss=array_dist_pl;
array_pathloss(:,2)=array_dist_pl(:,2)+array_clutter(nn_idx,2);
%%%%%%%%%


%%%%%%%%%Add Building Entry Loss: 15dB
bel_dB=15; %%%%%%Placeholder
array_pathloss_bel=array_pathloss;
array_pathloss_bel(:,2)=array_pathloss(:,2)+bel_dB;


%%%%%%%
cross_idx=nearestpoint_app(app,required_pathloss,array_pathloss_bel(:,2))
array_pathloss_bel(cross_idx,:)

figure;
hold on;
%plot(array_dist_pl(:,1),array_dist_pl(:,2),'-ok')
%plot(array_pathloss(:,1),array_pathloss(:,2),'-og')
plot(array_pathloss_bel(:,1),array_pathloss_bel(:,2),'-or')
xline(array_pathloss_bel(cross_idx,1))
yline(required_pathloss)
xlabel('Distance [km]')
ylabel('Pathloss [dB]')
grid on;
filename1=strcat('Pathloss_Shure.png');
saveas(gcf,char(filename1))
pause(0.1);



'Next step: Horizontal/Vertical line distance for required pathloss'

%%%%%%%%%Then do the knn between the radars and the fifa locations, finding the minimum distances.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%'Pull in the  kmz': https://uavsar.jpl.nasa.gov/kml/FAA_LongRangeRadars.kml
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
stc_kml=kmz2struct('FAA_LongRangeRadars.kml');
temp_table_kml=struct2table(stc_kml);
temp_cell_kml=table2cell(temp_table_kml(:,[3,6]))

%%%%%%Process the site name to get a unique Id
[num_rows,~]=size(temp_cell_kml);
array_latlon=NaN(num_rows,2);
for i=1:1:num_rows
    temp_str=temp_cell_kml{i,1};
    temp_split=strsplit(temp_str,'Latitude:');
    temp_split2=strsplit(temp_split{2},'Longitude:');

    temp_split3=strsplit(temp_split2{1},'<br>');
    temp_split4=strsplit(temp_split2{2},'<br>');

    temp_lat=str2num(temp_split3{1});
    temp_lon=str2num(temp_split4{1});
    array_latlon(i,1)=temp_lat;
    array_latlon(i,2)=temp_lon;
end


%%%%%%%%%%%%Fifa Stadiums
tf_repull=0
excel_filename='fifa_stadiums.xlsx'
mat_filename_str=strcat('fifa_latlon.mat')
[cell_fifa_data]=load_full_excel_rev1(app,mat_filename_str,excel_filename,tf_repull);
cell_fifa_data_cut=cell_fifa_data(2:end,:);
[num_stad,~]=size(cell_fifa_data_cut)
for i=1:1:num_stad
    example_data=cell_fifa_data_cut{i,3};
    cell_fifa_data_cut{i,3}=-1*str2double(example_data(2:end));
end
cell_fifa_data_cut


%%%%%%%%Find the min distance as a check
stadium_pts=cell2mat(cell_fifa_data_cut(:,[2,3]))
[idx_knn]=knnsearch(array_latlon,stadium_pts,'k',1); %%%Find Nearest Neighbor
knn_array=array_latlon(idx_knn,:);
knn_dist_bound=deg2km(distance(knn_array(:,1),knn_array(:,2),stadium_pts(:,1),stadium_pts(:,2)));%%%%Calculate Distance
min_knn_dist=floor(min(knn_dist_bound))


%%%%%%%%%%%%'Now write an excel table'
table_stadium_data=cell2table(horzcat(cell_fifa_data_cut,num2cell(knn_dist_bound)))
table_stadium_data.Properties.VariableNames={'Name' 'Lat' 'Lon' 'Nearest_Radar_km'}
writetable(table_stadium_data,strcat('Fifa_stadium_data.xlsx'));






