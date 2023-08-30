//
//  ViewController.swift
//  RxDataSourceTest
//
//  Created by LongMa on 2023/8/30.
//

import UIKit
import RxDataSources
import RxSwift
import RxRelay

enum Consts:String {
    case cellReuseID = "cellReuseID"
}

struct ContactModel {
    var age:Int
    var name:String
}

struct ContactSectionModel {
    var sectionName:String
    var items: [ContactModel]{
        set {
            _items = newValue
        }
        get {
            return isFold ? [] : _items
        }
    }
    
    var isFold : Bool = false
    private var _items :[ContactModel] = []
    
    mutating func toggleFoldState() {
        isFold = !isFold
    }
    
    init(sectionName: String, items: [ContactModel]) {
        self.sectionName = sectionName
        self.items = items
    }
}

extension ContactSectionModel:SectionModelType {
    init(original: ContactSectionModel, items: [ContactModel]) {
        self = original
        self.items = items
    }
}

class ViewController: UIViewController {
    
    private var tableView = UITableView.init()
    private var bag = DisposeBag()
    private var isEditingOfTableView = false
    
    private let dataRelay = BehaviorRelay.init(value:
        [
            ContactSectionModel(sectionName: "family",
                                items: [ContactModel(age: 18, name: "bro"),
                                        ContactModel(age: 20, name: "sister"),
                                        ContactModel(age: 58, name: "father"),
                                        ContactModel(age: 60, name: "mom"),
                                       ]),
            ContactSectionModel(sectionName: "friends",
                                items: [ContactModel(age: 21, name: "a"),
                                        ContactModel(age: 22, name: "b"),
                                        ContactModel(age: 23, name: "c"),
                                        ContactModel(age: 24, name: "d"),
                                       ]),
            ContactSectionModel(sectionName: "workmates",
                                items: [ContactModel(age: 31, name: "work0"),
                                        ContactModel(age: 32, name: "work1"),
                                        ContactModel(age: 33, name: "work2"),
                                        ContactModel(age: 34, name: "work3"),
                                       ])
        ])
    
    override func loadView() {
        view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let headerV = UIView.init(frame: CGRect.init(x: 0, y: 0, width: view.bounds.width, height: 44))
        let editingSwitch = UISwitch.init(frame: CGRect.init(x: 200, y: 0, width: 100, height: 44))
        editingSwitch.rx.value.subscribe { isOn in
            self.isEditingOfTableView = isOn
            self.tableView.setEditing(isOn, animated: true)
        }.disposed(by: bag)
        headerV.addSubview(editingSwitch)
        
        let label = UILabel.init(frame: CGRect.init(x: 100, y: 0, width: 100, height: 44))
        headerV.addSubview(label)
        label.text = "editingState"
        
        tableView.tableHeaderView = headerV
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Consts.cellReuseID.rawValue)
        
        let dataSource = RxTableViewSectionedReloadDataSource<ContactSectionModel> { dataSour, tv, indexPath, item in
            let cell = tv.dequeueReusableCell(withIdentifier: Consts.cellReuseID.rawValue, for: indexPath)
            cell.textLabel?.text = item.name + ",\(item.age),\(indexPath)"
            
            return cell
        }
        //    titleForHeaderInSection: { dataSour, sect in
        //            dataSour.sectionModels[sect].sectionName
        //        }
        
        //canEdit和canMove都是数据源方法！！！不是代理方法。且必须设置 setEditing:true
    canEditRowAtIndexPath: { dataSour, indexPath in
        true
    }
        //若canEditRowAtIndexPath返回false，则canMoveRowAtIndexPath无效。canEditRowAtIndexPath返回true时，canMoveRowAtIndexPath控制是否显示移动按钮
    canMoveRowAtIndexPath: { dataSour, indexPath in
        true
    }
        
        //It enables using normal delegate mechanism with reactive delegate mechanism.设置后，同时生效！！！eg：rx.itemSelected和didSelectRowAtIndexPath会同时触发
        tableView.rx.setDelegate(self).disposed(by: bag)
        
        dataRelay
            .bind(to: tableView.rx.items(dataSource: dataSource)).disposed(by: bag)
        
        //移动cell后，更新数据源（直接使用dataSource.sectionModels更新到dataRelay）
        tableView.rx.itemMoved.subscribe { itemMovedEvent in
            self.dataRelay.accept(dataSource.sectionModels)
        }.disposed(by: bag)
        
        //删除cell后，更新数据源（根据删除cell的indexPath更新）
        tableView.rx.itemDeleted.subscribe { indexPath in
            var sectionModelsArr = self.dataRelay.value
            sectionModelsArr[indexPath.section].items.remove(at: indexPath.row)
            self.dataRelay.accept(sectionModelsArr)
            
            //实测下面方法不行！
            //            self.dataRelay.accept(dataSource.sectionModels)
        }.disposed(by: bag)
        
        //cell click
        tableView.rx.itemSelected.subscribe { indexPath in
            print(indexPath)
        }.disposed(by: bag)
        
    }
}

extension ViewController:UITableViewDelegate {
    
    //  //想要左滑删除，必须实现此代理方法 + canEditRowAtIndexPath返回true + 不能设置 setEditing:true;
    //    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    //        .delete
    //    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(#function, indexPath)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var dataArr = dataRelay.value
        var sectionModel = dataArr[section]
        let btn = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 100, height: 60))
        btn.setTitle(sectionModel.sectionName + (sectionModel.isFold ? "▽" : "▷"), for: .normal)
        btn.setTitleColor(.orange, for: .normal)
        
        btn.rx.tap
            .filter({
                return !self.isEditingOfTableView
            })
            .subscribe(onNext: {
                sectionModel.toggleFoldState()
                dataArr[section] = sectionModel
                self.dataRelay.accept(dataArr)
            }).disposed(by: bag)
        return btn
    }
}

