###########################################################
####  19-06-2020
####  Dependencies , Pre trained models and weights ########
############################################################
1. Install dependencies
  * Run ./install.sh
  * Download and install darkflow from https://github.com/thtrieu/darkflow

2. Downlaod Darkflow's yolo2-tiny configuration file and weights file
  * tiny-yolo-voc.weights
      https://drive.google.com/drive/folders/0B1tW_VtY7onidEwyQ2FtQVplWEU
  * tiny-yolo-voc.cfg
      https://github.com/thtrieu/darkflow/blob/master/cfg/tiny-yolo-voc.cfg
  * yolo2_tiny_dnnweaver2_weights.pickle 
      https://drive.google.com/open?id=1C4_3lnunikxNMSZydHRYhKD7Zd86PyYL
  * yolo2_tiny_tf_weights.pickle
      https://drive.google.com/open?id=10J0CZ8ITNZpP24JwXrhr1kEAtro80k39

3. Locate the files
  * tiny-yolo-voc.weights -> weights/
  * tiny-yolo-voc.cfg -> conf/


####  Run the command to perfrom object detection process #####
4. Run
  * PYTHONPATH=:.. python yolo_demo.py test.jpg weights/yolo2_tiny_tf_weights.pickle weights/yolo2_tiny_dnnweaver2_weights.pickle

 use the below script to run the detection
   > source ../../env/.rctensorflow     ( invoke tf environment) 
   > ./run.sh >& run.log 		( run detection applicaion demo)


#### Results 
 input image :  test.jpg 
 output image : bbox-test.jpg 

#### Open the image in linux 
  > shotwell bbox-test.jpg 





